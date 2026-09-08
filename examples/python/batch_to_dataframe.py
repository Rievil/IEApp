#!/usr/bin/env python3
"""
Collect every IEApp measurement in a folder into one pandas DataFrame.

    python batch_to_dataframe.py path/to/folder                 # print overview
    python batch_to_dataframe.py folder --out all.pkl           # DataFrame incl. waveforms (pickle)
    python batch_to_dataframe.py folder --out all.parquet       # metadata + labels + features (no waveforms)
    python batch_to_dataframe.py folder --out all.csv --waveforms waves.npz

One row per stored signal.  Columns: File, the SignalsTable columns, the
descriptive variables of DescTable (joined on ID) and two derived features:
PeakAmplitude and DominantFrequency (Hz, same method as the IEApp FFT panel).
Waveforms stay in the ``Signal`` column (numpy arrays) for pickle output, or
are written to an .npz file (key ``<file stem>_<ID>``) with ``--waveforms``.

Requires numpy, scipy, pandas (pyarrow for parquet).
"""
import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.io import whosmat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ieapp_mat import amplitude_spectrum, dominant_frequency, load_ieapp  # noqa: E402


def is_ieapp_file(path: Path) -> bool:
    """Cheap pre-check: the file has a variable called ``stash``.

    ``whosmat`` fails on some files holding top-level MATLAB objects; in that
    case return True and let ``load_ieapp`` decide.
    """
    try:
        return any(name == "stash" for name, _, _ in whosmat(str(path)))
    except Exception:
        return True


def load_folder(folder: Path, pattern: str = "*.mat", features: bool = True) -> pd.DataFrame:
    frames = []
    for path in sorted(folder.rglob(pattern)):
        if not is_ieapp_file(path):
            print(f"skip (not IEApp): {path.name}")
            continue
        try:
            meas = load_ieapp(str(path))
        except ValueError as err:  # e.g. old stash layout or no 'stash' variable
            print(f"skip: {err}")
            continue
        df = meas.to_dataframe()
        df["File"] = path.name
        if features and meas.n_signals:
            peaks, doms = [], []
            for i in range(meas.n_signals):
                t, y = meas.waveform(i)
                fs = float(meas.signals["SamplingFrequency"][i])
                f, amp = amplitude_spectrum(y, fs)
                fd, _ = dominant_frequency(f, amp, fmin=60, fmax=meas.daq.get("MaxFreq") or fs / 2)
                peaks.append(float(np.abs(y).max()))
                doms.append(fd)
            df["PeakAmplitude"] = peaks
            df["DominantFrequency"] = doms
        print(f"{path.name}: {meas.n_signals} signals, labels={[m['name'] for m in meas.markers]}")
        frames.append(df)
    if not frames:
        return pd.DataFrame()
    return pd.concat(frames, ignore_index=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folder")
    ap.add_argument("--pattern", default="*.mat")
    ap.add_argument("--out", help="output table: .pkl (keeps waveforms), .parquet or .csv (drops waveforms)")
    ap.add_argument("--waveforms", metavar="NPZ", help="also store all waveforms in a compressed .npz")
    ap.add_argument("--no-features", action="store_true", help="skip PeakAmplitude / DominantFrequency")
    args = ap.parse_args()

    df = load_folder(Path(args.folder), args.pattern, features=not args.no_features)
    if df.empty:
        print("no IEApp files found")
        return 1
    print(f"\n{len(df)} signals from {df['File'].nunique()} files")
    print(df.drop(columns=["Signal"]).head(10).to_string())

    if args.waveforms:
        waves = {f"{Path(r.File).stem}_{int(r.ID)}": np.asarray(r.Signal, dtype=np.float32)
                 for r in df.itertuples(index=False)}
        np.savez_compressed(args.waveforms, **waves)
        print(f"wrote {args.waveforms} ({len(waves)} waveforms)")

    if args.out:
        out = Path(args.out)
        if out.suffix == ".pkl":
            df.to_pickle(out)
        elif out.suffix == ".parquet":
            df.drop(columns=["Signal"]).to_parquet(out, index=False)
        else:
            df.drop(columns=["Signal"]).to_csv(out, index=False)
        print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
