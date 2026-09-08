"""
ieapp_mat.py - read IEApp measurement files (*.mat) in Python.

IEApp (https://github.com/Rievil/IEApp) stores one measurement session in a
MATLAB v7 MAT-file that contains a single struct variable called ``stash``.
Signals and their labels are MATLAB ``table`` objects.  ``scipy.io.loadmat``
can open the file, but MATLAB class objects (``table``, ``datetime``,
``categorical``, ``string``) are returned as ``MatlabOpaque`` placeholders,
because their content is serialised in a separate "subsystem" block that
scipy exposes as the raw byte array ``__function_workspace__``.

This module decodes that block (MATLAB's MCOS object serialisation) and
returns plain Python / numpy objects, so a measurement can be used directly:

    >>> from ieapp_mat import load_ieapp
    >>> meas = load_ieapp("T82-P-Kroutiva.mat")
    >>> meas.n_signals
    54
    >>> meas.signals["ID"][:3], meas.signals["SamplingFrequency"][0]
    (array([811., 812., 813.]), 44100.0)
    >>> t, y = meas.waveform(0)          # time axis [s] and amplitude of signal #0
    >>> df = meas.to_dataframe()         # pandas: signals + descriptors joined on ID

Only numpy and scipy are required.  pandas is optional (``to_dataframe``).
Tested with scipy 1.16 and 1.18 and files written by IEApp from MATLAB R2024a.

Command line:  python ieapp_mat.py measurement.mat
"""
from __future__ import annotations

import io
import os
import sys
from dataclasses import dataclass, field
from typing import Any

import numpy as np
from scipy.io import loadmat
from scipy.io.matlab import MatlabOpaque

try:  # scipy >= 1.8
    from scipy.io.matlab._mio5 import MatFile5Reader
except ImportError:  # pragma: no cover - very old scipy
    from scipy.io.matlab.mio5 import MatFile5Reader  # type: ignore

__all__ = [
    "load_ieapp",
    "load_stash",
    "load_mat_with_objects",
    "Measurement",
    "MatTable",
    "amplitude_spectrum",
    "dominant_frequency",
]

# --------------------------------------------------------------------------
# Generic MAT-file helpers
# --------------------------------------------------------------------------


def _simplify(x: Any, subsystem: "_McosSubsystem | None") -> Any:
    """Turn the numpy objects produced by scipy into plain Python/numpy values.

    * MATLAB struct  -> dict (or list of dicts for struct arrays)
    * MATLAB cell    -> list (nested lists for 2-D cells with >1 column)
    * char array     -> str (or list of str)
    * 1x1 numeric    -> Python scalar, n x 1 numeric -> 1-D numpy array
    * MatlabOpaque   -> decoded MATLAB object (table, datetime, ...)
    """
    if isinstance(x, MatlabOpaque):
        if subsystem is None:
            return x
        return subsystem.resolve(x)
    if subsystem is not None and isinstance(x, np.ndarray) and x.dtype == np.uint32 and _is_object_ref(x):
        # inside the subsystem, nested objects are stored as plain uint32 reference arrays
        return subsystem.resolve_ref(x)
    if isinstance(x, dict):
        return {k: _simplify(v, subsystem) for k, v in x.items()}
    if isinstance(x, (list, tuple)):
        return [_simplify(v, subsystem) for v in x]
    if not isinstance(x, np.ndarray):
        return x
    if x.dtype.names:  # struct array
        recs = [
            {name: _simplify(rec[name], subsystem) for name in x.dtype.names}
            for rec in x.ravel()
        ]
        return recs[0] if x.size == 1 else recs
    if x.dtype == object:  # cell array
        if x.ndim == 2 and x.shape[0] > 1 and x.shape[1] > 1:
            return [[_simplify(v, subsystem) for v in row] for row in x]
        return [_simplify(v, subsystem) for v in x.ravel()]
    if x.dtype.kind in ("U", "S"):  # char array
        if x.size == 0:
            return ""
        vals = [str(v) for v in x.ravel()]
        return vals[0] if len(vals) == 1 else vals
    # numeric / logical
    if x.size == 0:
        return x.reshape(0)
    if x.size == 1:
        return x.ravel()[0].item()
    if x.ndim == 2 and min(x.shape) == 1:
        return x.ravel()
    return x


def _is_object_ref(x: np.ndarray) -> bool:
    """True if ``x`` is an MCOS object reference ``[0xDD00xxxx, ndims, dims.., ids.., class_id]``."""
    v = x.ravel()
    if v.size < 4 or (int(v[0]) >> 16) != 0xDD00:
        return False
    ndims = int(v[1])
    if ndims < 1 or v.size < 2 + ndims + 1:
        return False
    count = int(np.prod(v[2 : 2 + ndims]))
    return v.size == 2 + ndims + count + 1


def _opaque_fields(op: MatlabOpaque) -> tuple[str, np.ndarray]:
    """Return (class name, metadata uint32 array) of a MatlabOpaque record.

    scipy < 1.18 uses fields (s0, s1, s2, arr); scipy >= 1.18 uses
    (_TypeSystem, _Class, _ObjectMetadata).  In both, the last two fields
    are the class name and the metadata array.
    """
    rec = op.ravel()[0]
    names = op.dtype.names
    cls = rec[names[-2]]
    if isinstance(cls, bytes):
        cls = cls.decode("latin1")
    meta = np.asarray(rec[names[-1]]).ravel()
    return str(cls), meta


# --------------------------------------------------------------------------
# MCOS subsystem decoder
# --------------------------------------------------------------------------


@dataclass
class MatObject:
    """A decoded MATLAB class object that has no special conversion."""

    class_name: str
    props: dict[str, Any]


@dataclass
class MatTable:
    """Decoded MATLAB ``table``: a dict of equally long columns.

    ``columns[name]`` is a 1-D numpy array (numeric / datetime64 / str) or a
    Python list (cell columns, e.g. one waveform array per row).
    """

    columns: dict[str, Any]
    nrows: int
    row_names: list[str] = field(default_factory=list)
    categories: dict[str, list[str]] = field(default_factory=dict)
    units: dict[str, str] = field(default_factory=dict)
    descriptions: dict[str, str] = field(default_factory=dict)

    @property
    def names(self) -> list[str]:
        return list(self.columns)

    def __len__(self) -> int:
        return self.nrows

    def __getitem__(self, name: str) -> Any:
        return self.columns[name]

    def __contains__(self, name: str) -> bool:
        return name in self.columns

    def row(self, i: int) -> dict[str, Any]:
        return {k: v[i] for k, v in self.columns.items()}

    def to_dataframe(self):
        """Convert to a pandas DataFrame (pandas required)."""
        import pandas as pd

        data = {}
        for name, col in self.columns.items():
            if name in self.categories:
                col = pd.Categorical(col, categories=self.categories[name])
            elif isinstance(col, list):
                col = pd.Series(col, dtype=object)
            elif isinstance(col, np.ndarray) and col.ndim > 1:
                col = pd.Series(list(col), dtype=object)  # matrix column -> one row per entry
            data[name] = col
        return pd.DataFrame(data)

    def __repr__(self) -> str:
        return f"MatTable({self.nrows} rows, columns={self.names})"


class _McosSubsystem:
    """Parser for the ``__function_workspace__`` block (MATLAB MCOS objects).

    Layout (reverse engineered, MATLAB R2019-R2024 files):

    * The block is a MAT-5 stream without the 128-byte file header: 8 bytes
      (version + endian tag + padding) followed by one miMATRIX struct with a
      single field ``MCOS`` holding an opaque ``FileWrapper__`` object whose
      metadata is a cell array ``cells``.
    * ``cells[0]``  uint8 metadata blob: header, names, class table, object
      table and property lists.
    * ``cells[2:]`` property values; a property-list value index ``v`` refers
      to ``cells[v + 2]``.
    * the last three cells hold per-class default values (not needed here).

    Metadata blob:  int32 header ``[version, n_names, off_1 .. off_8]`` (40
    bytes), then ``n_names`` NUL-terminated names, then regions at the given
    offsets:  1 class table (4 int32 per class: ``[ns, name, 0, 0]``),
    2 "type 1" property lists, 3 object table (6 int32 per object:
    ``[class_id, 0, 0, type1_list, type2_list, save_order]``),
    4 "type 2" property lists, 5 unused.  A property list is
    ``n, (name_idx, value_type, value) * n`` padded to 8 bytes, where
    value_type 0 = value is a name index (string), 1 = index into ``cells``,
    2 = literal number.
    """

    def __init__(self, blob: np.ndarray):
        raw = np.ascontiguousarray(blob, dtype=np.uint8).tobytes()
        self.byte_order = "<" if raw[2:4] == b"IM" else ">"
        reader = MatFile5Reader(io.BytesIO(raw))
        reader.byte_order = self.byte_order
        reader.mat_stream.seek(8)
        reader.initialize_read()
        header, _ = reader.read_var_header()
        wrapper = reader.read_var_array(header, process=True)
        mcos = wrapper["MCOS"][0, 0]
        _, cells = _opaque_fields(mcos)  # metadata array *is* the cell array
        self.cells = np.asarray(cells, dtype=object).ravel()
        self._parse_metadata(self.cells[0].tobytes())
        self._cache: dict[int, Any] = {}

    # -- metadata ---------------------------------------------------------
    def _i32(self, buf: bytes, start: int, stop: int) -> np.ndarray:
        return np.frombuffer(buf[start:stop], dtype=self.byte_order + "i4")

    def _parse_metadata(self, mb: bytes) -> None:
        hdr = self._i32(mb, 0, 40)
        self.version = int(hdr[0])
        n_names = int(hdr[1])
        offsets = [int(v) for v in hdr[2:10]]
        names_raw = mb[40 : offsets[0]].split(b"\x00")
        self.names = [s.decode("utf-8", "replace") for s in names_raw if s][:n_names]

        cls = self._i32(mb, offsets[0], offsets[1]).reshape(-1, 4)
        self.classes = [self._name(int(c[1])) for c in cls]  # classes[0] is dummy ''

        self.type1_lists = self._parse_prop_lists(mb, offsets[1], offsets[2])
        self.objects = self._i32(mb, offsets[2], offsets[3]).reshape(-1, 6)
        self.type2_lists = self._parse_prop_lists(mb, offsets[3], offsets[4])

    def _name(self, idx: int) -> str:
        return self.names[idx - 1] if idx > 0 else ""

    def _parse_prop_lists(self, mb: bytes, start: int, stop: int) -> list:
        ints = self._i32(mb, start, stop)
        lists: list = [None]  # index 0 = "no list"
        pos = 2  # skip leading [0, 0]
        while pos < len(ints):
            n = int(ints[pos])
            pos += 1
            props = []
            for _ in range(n):
                name_idx, vtype, value = (int(v) for v in ints[pos : pos + 3])
                pos += 3
                props.append((self._name(name_idx), vtype, value))
            lists.append(props)
            if (pos * 4) % 8:  # entries are 8-byte aligned
                pos += 1
        return lists

    # -- objects ----------------------------------------------------------
    def object_props(self, obj_id: int) -> tuple[str, dict[str, Any]]:
        """Return (class name, {property: value}) for object ``obj_id``."""
        entry = self.objects[obj_id]
        class_name = self.classes[int(entry[0])]
        props: dict[str, Any] = {}
        for lst_idx, lists in ((int(entry[3]), self.type1_lists), (int(entry[4]), self.type2_lists)):
            if lst_idx <= 0:
                continue
            for name, vtype, value in lists[lst_idx]:
                if vtype == 1:
                    props[name] = _simplify(self.cells[value + 2], self)
                elif vtype == 0:
                    props[name] = self._name(value)
                else:
                    props[name] = value
        return class_name, props

    def resolve(self, op: MatlabOpaque) -> Any:
        """Decode a MatlabOpaque placeholder found in the main file."""
        class_name, meta = _opaque_fields(op)
        if not _is_object_ref(np.asarray(meta)):
            return MatObject(class_name, {"_metadata": meta})
        return self.resolve_ref(meta)

    def resolve_ref(self, meta: np.ndarray) -> Any:
        """Decode an object reference array ``[magic, ndims, dims.., ids.., class_id]``."""
        meta = np.asarray(meta).ravel()
        ndims = int(meta[1])
        dims = [int(d) for d in meta[2 : 2 + ndims]]
        count = int(np.prod(dims)) if dims else 0
        obj_ids = [int(v) for v in meta[2 + ndims : 2 + ndims + count]]
        objs = [self._convert(i) for i in obj_ids]
        if count == 1:
            return objs[0]
        return objs

    def _convert(self, obj_id: int) -> Any:
        if obj_id in self._cache:
            return self._cache[obj_id]
        class_name, props = self.object_props(obj_id)
        conv = _CONVERTERS.get(class_name)
        value = conv(props) if conv else MatObject(class_name, props)
        self._cache[obj_id] = value
        return value


# --------------------------------------------------------------------------
# Converters for the MATLAB classes used by IEApp
# --------------------------------------------------------------------------


def _as_str_list(x: Any) -> list[str]:
    if x is None:
        return []
    if isinstance(x, str):
        return [x]
    if isinstance(x, np.ndarray):
        x = x.ravel().tolist()
    return [str(v) for v in x]


def _convert_table(props: dict[str, Any]) -> MatTable:
    nrows = int(props.get("nrows", 0) or 0)
    varnames = _as_str_list(props.get("varnames", []))
    data = props.get("data", [])
    if not isinstance(data, list):
        data = [data]
    columns: dict[str, Any] = {}
    categories: dict[str, list[str]] = {}
    for name, col in zip(varnames, data):
        if isinstance(col, _Categorical):
            categories[name] = col.categories
            col = col.values
        elif isinstance(col, list):
            col = _tidy_cell_column(col)
        elif isinstance(col, (int, float, complex, str, bool)) and nrows == 1:
            col = np.asarray([col])
        columns[name] = col
    tprops = props.get("props", {}) or {}
    if not isinstance(tprops, dict):
        tprops = {}

    def _meta(key: str) -> dict[str, str]:
        vals = _as_str_list(tprops.get(key, []))
        return {k: v for k, v in zip(varnames, vals) if v}

    return MatTable(
        columns=columns,
        nrows=nrows,
        row_names=_as_str_list(props.get("rownames", [])),
        categories=categories,
        units=_meta("VariableUnits"),
        descriptions=_meta("VariableDescriptions"),
    )


def _tidy_cell_column(col: list) -> Any:
    """Cell column -> numeric array if every cell is a scalar, else list."""
    if col and all(isinstance(v, (int, float, bool)) and not isinstance(v, str) for v in col):
        return np.asarray(col, dtype=float)
    if col and all(isinstance(v, str) for v in col):
        return np.asarray(col, dtype=object)
    return [np.asarray(v).ravel() if isinstance(v, np.ndarray) else v for v in col]


def _convert_datetime(props: dict[str, Any]) -> np.ndarray:
    """MATLAB datetime -> numpy datetime64[us].

    MATLAB stores datetimes as complex doubles: real part = milliseconds
    since 1970-01-01 (wall-clock time treated as UTC when no time zone is
    set), imaginary part = sub-millisecond remainder.
    """
    data = np.atleast_1d(np.asarray(props.get("data", [])))
    ms = np.real(data).astype(np.float64) + np.imag(data).astype(np.float64)
    us = np.round(ms * 1000.0).ravel()
    out = np.full(us.shape, np.datetime64("NaT", "us"))
    ok = np.isfinite(us)
    out[ok] = us[ok].astype("int64").astype("datetime64[us]")
    return out


@dataclass
class _Categorical:
    values: np.ndarray  # object array of str / None
    categories: list[str]


def _convert_categorical(props: dict[str, Any]) -> _Categorical:
    cats = _as_str_list(props.get("categoryNames", []))
    codes = np.asarray(props.get("codes", []), dtype=np.int64).ravel()
    values = np.empty(codes.shape, dtype=object)
    for i, c in enumerate(codes):
        values[i] = cats[c - 1] if 0 < c <= len(cats) else None
    return _Categorical(values, cats)


def _convert_string(props: dict[str, Any]) -> Any:
    """MATLAB string array -> str (1x1) or numpy object array of str."""
    blob = np.asarray(props.get("any", []), dtype=np.uint64).ravel()
    if blob.size < 2:
        return ""
    ndims = int(blob[1])
    dims = [int(v) for v in blob[2 : 2 + ndims]]
    n = int(np.prod(dims)) if dims else 0
    lengths = [int(v) for v in blob[2 + ndims : 2 + ndims + n]]
    chars = blob[2 + ndims + n :].tobytes()
    out, pos = [], 0
    for length in lengths:
        out.append(chars[pos : pos + 2 * length].decode("utf-16-le", "replace"))
        pos += 2 * length
    if n == 1:
        return out[0]
    arr = np.asarray(out, dtype=object)
    if len(dims) == 2 and min(dims) > 1:
        return arr.reshape(dims, order="F")  # MATLAB is column-major
    return arr


_CONVERTERS = {
    "table": _convert_table,
    "datetime": _convert_datetime,
    "categorical": _convert_categorical,
    "string": _convert_string,
}


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------


def load_mat_with_objects(path: str) -> dict[str, Any]:
    """``scipy.io.loadmat(path, simplify_cells=True)`` plus decoding of MATLAB
    class objects (table, datetime, categorical, string).

    Returns the usual loadmat dict without the ``__function_workspace__`` key.
    """
    raw = loadmat(path, simplify_cells=True)
    blob = raw.pop("__function_workspace__", None)
    subsystem = _McosSubsystem(blob) if blob is not None else None
    return {k: (v if k.startswith("__") else _simplify(v, subsystem)) for k, v in raw.items()}


def load_stash(path: str) -> dict[str, Any]:
    """Return the decoded ``stash`` struct of an IEApp measurement file."""
    data = load_mat_with_objects(path)
    if "stash" not in data:
        raise ValueError(f"{path!r} is not an IEApp measurement: no 'stash' variable "
                         f"(found {[k for k in data if not k.startswith('__')]})")
    return data["stash"]


@dataclass
class Measurement:
    """One IEApp measurement session (one *.mat file)."""

    path: str
    signals: MatTable          # stash.SignalsTable  - one row per stored signal
    descriptors: MatTable      # stash.Marker.DescTable - labels, one row per signal
    markers: list[dict]        # definition of the descriptive variables
    daq: dict                  # acquisition settings (trigger, sampling rate, ...)
    template_name: str
    stash: dict                # the complete decoded stash struct

    # -- convenience -------------------------------------------------------
    @property
    def n_signals(self) -> int:
        return self.signals.nrows

    @property
    def ids(self) -> np.ndarray:
        return np.asarray(self.signals["ID"], dtype=int)

    def time_axis(self, i: int) -> np.ndarray:
        """Time axis [s] of signal ``i`` (0 = trigger instant), as plotted by IEApp."""
        row = self.signals.row(i)
        return np.linspace(row["StartTime"], row["EndTime"], int(row["Samples"]))

    def waveform(self, i: int) -> tuple[np.ndarray, np.ndarray]:
        """(time [s], amplitude) of signal ``i`` (0-based row index)."""
        return self.time_axis(i), np.asarray(self.signals["Signal"][i], dtype=float).ravel()

    def to_dataframe(self, merge: bool = True):
        """pandas DataFrame: one row per signal.

        With ``merge=True`` the descriptive variables are joined on ``ID`` and
        the waveform arrays are kept in the ``Signal`` column.
        """
        import pandas as pd

        df = self.signals.to_dataframe()
        if merge and self.descriptors.nrows and "ID" in self.descriptors:
            desc = self.descriptors.to_dataframe()
            df = df.merge(desc, on="ID", how="left", suffixes=("", "_label"))
        df.insert(0, "File", os.path.basename(self.path))
        return df

    def summary(self) -> str:
        lines = [
            f"IEApp measurement: {self.path}",
            f"  template          : {self.template_name}",
            f"  signals           : {self.n_signals}",
        ]
        if self.n_signals:
            r = self.signals.row(0)
            lines += [
                f"  sampling rate     : {r.get('SamplingFrequency')} Hz",
                f"  samples/signal    : {int(r.get('Samples', 0))} "
                f"({r.get('StartTime'):.4f} .. {r.get('EndTime'):.4f} s around trigger)",
                f"  trigger           : {self.daq.get('TriggerLevel')} V, "
                f"delay {self.daq.get('TriggerDelay')} s, {self.daq.get('TriggerType')}",
                f"  first / last time : {self.signals['Time'][0]} / {self.signals['Time'][-1]}",
            ]
        lines.append("  descriptors       :")
        for m in self.markers:
            extra = f" classes={m['classes']}" if m.get("classes") else ""
            lines.append(f"    - {m['name']} ({m['type']}){extra}")
        return "\n".join(lines)


def _markers_from_stash(marker: dict) -> list[dict]:
    table = marker.get("MarkerTable")
    if not isinstance(table, MatTable):
        return []
    out = []
    for i in range(table.nrows):
        row = table.row(i)
        spec = row.get("Type") if isinstance(row.get("Type"), dict) else {}
        classes = []
        specific = spec.get("Specific") if isinstance(spec, dict) else None
        if isinstance(specific, dict) and isinstance(specific.get("UnTable"), MatTable):
            classes = [str(c) for c in specific["UnTable"]["Class"]]
        out.append({
            "id": int(row.get("ID", i + 1)),
            "name": str(row.get("Name", spec.get("Name", ""))),
            "type": str(row.get("DataType", spec.get("Type", ""))),
            "classes": classes,
        })
    return out


def load_ieapp(path: str) -> Measurement:
    """Load an IEApp measurement file and return a :class:`Measurement`."""
    stash = load_stash(path)
    signals = stash.get("SignalsTable")
    if not isinstance(signals, MatTable):
        raise ValueError(
            f"{path!r}: 'stash' has no SignalsTable (keys: {list(stash)}). This is not a file "
            "written by the current IEApp; use load_stash()/load_mat_with_objects() to inspect it.")
    marker = stash.get("Marker", {}) if isinstance(stash.get("Marker"), dict) else {}
    desc = marker.get("DescTable")
    if not isinstance(desc, MatTable):
        desc = MatTable(columns={}, nrows=0)
    daq = dict(stash.get("DAQ", {}) or {})
    return Measurement(
        path=str(path),
        signals=signals,
        descriptors=desc,
        markers=_markers_from_stash(marker),
        daq=daq,
        template_name=str(stash.get("TemplateName", "")),
        stash=stash,
    )


# --------------------------------------------------------------------------
# Analysis helpers (mirror of the FFT panel in IEApp, App/Tools/Plotter.m)
# --------------------------------------------------------------------------


def amplitude_spectrum(y: np.ndarray, fs: float, window: bool = True) -> tuple[np.ndarray, np.ndarray]:
    """Single-sided amplitude spectrum as drawn by IEApp (``Plotter.MyFFT``).

    The app multiplies the signal by a periodic Hamming window first; pass
    ``window=False`` for the raw spectrum.  Returns ``(f [Hz], amplitude)``.
    """
    y = np.asarray(y, dtype=float).ravel()
    n = y.size
    if window:
        y = y * (0.54 - 0.46 * np.cos(2.0 * np.pi * np.arange(n) / n))
    p2 = np.abs(np.fft.fft(y)) / n
    p1 = p2[: n // 2 + 1].copy()
    p1[1:-1] *= 2.0
    f = fs * np.arange(n // 2 + 1) / n
    return f, p1


def dominant_frequency(f: np.ndarray, amp: np.ndarray, fmin: float = 60.0,
                       fmax: float | None = None, min_distance_hz: float = 100.0):
    """Approximation of the "Dominant frequency" marker of IEApp.

    IEApp uses ``findpeaks`` with MinPeakDistance 100 Hz and MinPeakProminence
    10 % of the spectrum maximum above ``fmin`` (60 Hz) and ranks peaks by
    ``prominence * height / width``.  Returns ``(frequency, amplitude)`` of
    the best peak, or ``(nan, nan)`` if there is none.
    """
    from scipy.signal import find_peaks

    f = np.asarray(f, float)
    amp = np.asarray(amp, float)
    sel = f > fmin
    if fmax is not None:
        sel &= f <= fmax
    fs_, as_ = f[sel], amp[sel]
    if fs_.size < 3:
        return float("nan"), float("nan")
    df = fs_[1] - fs_[0]
    peaks, props = find_peaks(as_, prominence=0.1 * as_.max(), distance=max(1, int(round(min_distance_hz / df))), width=1)
    if peaks.size == 0:
        return float("nan"), float("nan")
    score = props["prominences"] * as_[peaks] / props["widths"]
    best = peaks[np.argmax(score)]
    return float(fs_[best]), float(as_[best])


def _main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 1
    for p in argv[1:]:
        meas = load_ieapp(p)
        print(meas.summary())
        print("  signal columns    :", meas.signals.names)
        print("  descriptor columns:", meas.descriptors.names)
        if meas.n_signals:
            t, y = meas.waveform(0)
            print(f"  signal[0]         : {len(y)} samples, t={t[0]:.4f}..{t[-1]:.4f} s, "
                  f"peak {np.abs(y).max():.4g}")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
