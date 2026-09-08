![](https://github.com/Rievil/IEApp/blob/main/Ilustration/App_window.png)
# Impact-Echo application for microphone measurements
[![DOI](https://zenodo.org/badge/768488337.svg)](https://zenodo.org/doi/10.5281/zenodo.12204655)

MATLAB application for Impact-Echo measurements and data storage. It uses a DirectSound driver for connection to any type of microphone or sound card. The IEApp requires these toolboxes:

- data_acq_toolbox
- matlab
- signal_toolbox

> [!IMPORTANT]
> To connect to sound card you will also need to install [Data Acquisition Toolbox Support Package for Windows Sound Cards](https://www.mathworks.com/matlabcentral/fileexchange/45171-data-acquisition-toolbox-support-package-for-windows-sound-cards).

# Usage
The app allows the user to pick the input microphone. There is possibility to set threshold, length of signals, pre-trigger time, sampling frequency. The app also allows you to design a group of descriptive variables, which allows to label signals for the purpose of the designed experiment. The signals and descriptive variables are stored in two tables, which are exported. The app allows to create templates of descriptive variables and use it for similar type of experiments.

Start the app with `main` (or `main_app`) from the repository root. Measurements are saved with the disk icon in the toolbar and loaded with the folder icon; a saved file can be re-opened later to append more signals or to reuse the descriptive variables as a template.

# Data storage format

One measurement session is saved as **one MATLAB MAT-file (v7)** containing a **single struct variable named `stash`** (see `Pack` in [App/Asker.m](App/Asker.m)). Everything the app needs to restore a session is in this struct, including the two tables that carry the data:

```
stash
├── SignalsTable        table, one row per stored signal (the waveforms)
├── ID                  last used signal ID (running counter)
├── CurrIDSel           row selected in the GUI when saved (0 = none)
├── LockLabels          '1' = labels locked, '2' = labels follow the selected signal (GUI state)
├── UISwitchState       1 = "Automatic save" (every trigger stored), 0 = "Manual save" (space bar stores)
├── TemplateName        name of the descriptive-variable template (free text)
├── DAQ                 acquisition settings
│   ├── SamplingRate     Hz (sound-card rate, 16000..192000)
│   ├── TriggerLevel     trigger threshold in signal units
│   ├── TriggerDelay     s, negative = pre-trigger part (default -0.05)
│   ├── TriggerType      'Rising' | 'Falling'
│   ├── CaptureDuration  s, length of the stored window after the trigger delay (default 0.5)
│   ├── ViewTimeWindow   s, live-view window length (GUI)
│   ├── MaxFreq          Hz, upper limit of the FFT panel
│   └── AcData           1-row table with the last captured signal (same columns as SignalsTable, no ID)
└── Marker              descriptive variables ("markers"/"descriptors")
    ├── MarkerTable      table, one row per descriptive variable (definition)
    ├── DescTable        table, one row per stored signal (the labels), keyed by ID
    ├── Count            number of descriptive variables
    ├── IDMainH          internal counter for marker IDs
    └── ClickEdit        1 = editing a control edits the selected signal's label (GUI)
```

## `stash.SignalsTable` – the signals

| Column | Class | Meaning |
|---|---|---|
| `Time` | datetime | PC wall-clock time when the capture was completed (no time zone stored) |
| `Signal` | cell → double column vector `Samples×1` | waveform amplitude as delivered by the sound-card driver (nominally ±1 full scale; the app labels it "A [V]") |
| `StartTime` | double, s | time of the first sample relative to the trigger instant (≈ `TriggerDelay`, e.g. -0.05) |
| `EndTime` | double, s | time of the last sample relative to the trigger instant |
| `SamplingFrequency` | double, Hz | sampling rate of this signal |
| `Duration` | double, s | `Samples / SamplingFrequency` |
| `Samples` | double | number of samples, `round(CaptureDuration * fs) + 1` |
| `TriggerLevel` | double | trigger threshold used for this signal |
| `TriggerDelay` | double, s | pre-trigger time used for this signal |
| `ID` | double | running integer ID of the signal, **key to `DescTable`** |

The time axis of a signal is reconstructed exactly as the app plots it (`Plotter.PlotOsc`):
`t = linspace(StartTime, EndTime, Samples)`, so `t = 0` is the moment the signal crossed the trigger level.
The FFT panel uses a periodic Hamming window and a single-sided amplitude spectrum (`Plotter.MyFFT`); the "dominant frequency" marker is the `findpeaks` result above 60 Hz with the best `prominence·height/width` score.

## `stash.Marker.DescTable` – the labels

`DescTable` has the column `ID` plus one column per descriptive variable defined in `MarkerTable`, in the same order. Row *i* of `DescTable` describes the signal with the same `ID` in `SignalsTable` (both tables normally have identical `ID` columns, join on `ID` to be safe). The class of a label column depends on the marker type:

| Marker `DataType` | GUI control | Column class in `DescTable` |
|---|---|---|
| `string` | drop-down with fixed classes | `categorical` (categories = the classes defined in the marker) |
| `double` | numeric field | cell of scalar doubles |
| `text` | free text field | cell of char |
| `datetime` | date picker | `datetime` |

## `stash.Marker.MarkerTable` – the label definitions

| Column | Class | Meaning |
|---|---|---|
| `ID` | double | 1..Count |
| `DataType` | categorical | `double`, `string`, `datetime` or `text` |
| `Name` | string | column name used in `DescTable` |
| `Type` | cell of struct | packed `Field` object: `Type`, `Name`, `Specific`; for `string` markers `Specific.UnTable` is a table with the allowed classes in column `Class` |

A **template** file is a normal measurement file with zero rows in `SignalsTable` and `DescTable`; loading it restores the descriptive variables and acquisition settings.

> [!NOTE]
> The tables are MATLAB class objects (`table`, `datetime`, `categorical`, `string`). In the MAT-file they are serialised as MATLAB "MCOS" objects, which is why generic readers see them only as opaque placeholders (see the Python section). Files written by the current app version have identical column names; this layout has been stable in files from 2024 to 2026. Files saved by the 2022 development version have a different `stash` layout (`stash.Asker.SignalsTable` with columns `ID`, `Signals`, `Date`; `Settings`, `SignalStorage`, ...); the Python reader raises a clear error for them and `load_stash` still returns their content.

# Reading the data in MATLAB

```matlab
S = load('T82-P-Kroutiva.mat');          % S.stash
T = S.stash.SignalsTable;                 % waveforms
D = S.stash.Marker.DescTable;             % labels
J = join(T, D, 'Keys', 'ID');             % one row per signal with its labels

i = 1;
t = linspace(T.StartTime(i), T.EndTime(i), T.Samples(i));
plot(t, T.Signal{i}); xlabel('t [s]'); ylabel('A');
```

# Reading the data in Python

`scipy.io.loadmat(file, simplify_cells=True)` opens the file and returns `stash` as a nested `dict`, but every MATLAB `table`/`datetime`/`categorical`/`string` comes back as a `scipy.io.matlab.MatlabOpaque` placeholder (this is still true in scipy 1.18). The actual table contents are inside the byte array `__function_workspace__`, which scipy does not decode:

```python
from scipy.io import loadmat
m = loadmat("T82-P-Kroutiva.mat", simplify_cells=True)
m["stash"]["DAQ"]["SamplingRate"]     # 44100  -> plain values work
m["stash"]["SignalsTable"]            # MatlabOpaque(... 'MCOS', 'table' ...) -> not usable directly
```

The repository therefore ships a small, dependency-light reader that decodes this block: [examples/python/ieapp_mat.py](examples/python/ieapp_mat.py) (needs only `numpy` and `scipy`; `pandas` is optional). It was verified against MATLAB R2024a: all waveforms bit-identical, timestamps to the millisecond, all label columns and categories equal; tested with scipy 1.16 and 1.18 on 29 IEApp files from 2024–2026 (44.1 kHz and 192 kHz, 0 to 213 signals per file).

## Quick start

```bash
pip install numpy scipy pandas            # pandas only for DataFrames / CSV
python examples/python/ieapp_mat.py measurement.mat        # prints a summary of the file
```

```python
import sys; sys.path.append("examples/python")            # or copy ieapp_mat.py next to your script
from ieapp_mat import load_ieapp, amplitude_spectrum, dominant_frequency

meas = load_ieapp("T82-P-Kroutiva.mat")
meas.n_signals                     # 54
meas.template_name                 # 'Default'
meas.daq                           # {'TriggerLevel': 0.05, 'TriggerDelay': -0.05, 'SamplingRate': 44100, ...}
meas.markers                       # [{'id': 1, 'name': 'Typ', 'type': 'string', 'classes': ['Ref', '3D']}, ...]

meas.signals                       # MatTable: SignalsTable as a dict of columns
meas.signals["ID"]                 # array([811., 812., ...])
meas.signals["Time"]               # numpy datetime64[us] (wall-clock, naive)
meas.signals["Signal"][0]          # 1-D numpy array, 8821 samples
meas.descriptors                   # MatTable: DescTable (categorical columns -> str, .categories keeps the classes)
meas.descriptors["TypVlneni"][:3]  # array(['Kroutive', 'Kroutive', 'Kroutive'], dtype=object)

t, y = meas.waveform(0)            # time axis [s] (0 = trigger) and amplitude of the first signal
f, A = amplitude_spectrum(y, meas.signals["SamplingFrequency"][0])   # same FFT as the app panel
f_dom, A_dom = dominant_frequency(f, A, fmin=60, fmax=meas.daq["MaxFreq"])

df = meas.to_dataframe()           # pandas: one row per signal, SignalsTable + DescTable joined on ID,
                                   # column "File" = file name, waveforms kept in column "Signal",
                                   # categorical labels as pandas Categorical
```

`load_mat_with_objects(path)` returns the complete `loadmat` dictionary with all MATLAB objects decoded (tables become `MatTable`), and `load_stash(path)` returns just the decoded `stash`. Use these for files from other tools that also store tables, e.g. a table saved directly with `save('x.mat','T')` (note: scipy older than 1.18 reports such a top-level object under the key `'None'`).

## Example scripts

| Script | Purpose |
|---|---|
| [examples/python/ieapp_mat.py](examples/python/ieapp_mat.py) | reader module; `python ieapp_mat.py file.mat` prints a summary |
| [examples/python/read_measurement.py](examples/python/read_measurement.py) | inspect one file: summary, labels, one waveform, spectrum plot (`--plot out.png`), label table (`--csv`) |
| [examples/python/batch_to_dataframe.py](examples/python/batch_to_dataframe.py) | all files of a folder → one DataFrame with labels, peak amplitude and dominant frequency; `--out all.pkl/.parquet/.csv`, `--waveforms waves.npz` |

## Notes for automated analysis (AI agents, scripts)

1. Use `examples/python/ieapp_mat.py` (`load_ieapp`) instead of plain `scipy.io.loadmat`; the plain call cannot read the tables.
2. One file = one session; one row of `SignalsTable` = one impact; `DescTable` holds the experiment labels; join on `ID`.
3. Waveform `i`: `y = meas.signals["Signal"][i]`, `fs = meas.signals["SamplingFrequency"][i]`, `t = meas.time_axis(i)` (seconds, 0 = trigger, negative part = pre-trigger).
4. `Time` is the naive local wall-clock time of the measurement PC; `StartTime`/`EndTime`/`Duration` are in seconds, `SamplingFrequency` in Hz.
5. Label columns coming from `string` markers are categorical with a fixed class list (`meas.descriptors.categories[name]`); `double` markers are numeric, `text` markers are free text.
6. For many files use `batch_to_dataframe.py` or loop over `load_ieapp` and `pd.concat` the DataFrames.

## Alternative: `mat-io`

The third-party package [`mat-io`](https://pypi.org/project/mat-io/) (`pip install mat-io`, `from matio import load_from_mat`) also decodes MATLAB tables into pandas DataFrames. It returns structs as numpy record arrays (`stash["Marker"][0, 0]["DescTable"][0, 0]`) and categorical values as 1-tuples, so some post-processing is needed; version 1.0.0 read the example file correctly.

# Citation
If you use this software, please cite it as described in [citation.cff](citation.cff) (DOI 10.5281/zenodo.12204656).
