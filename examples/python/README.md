# Python examples for IEApp measurement files

See the section **Reading the data in Python** of the [main README](../../README.md) for the file format.

| File | Purpose |
|---|---|
| `ieapp_mat.py` | Reader module. `load_ieapp(path)` returns a `Measurement` (signals, descriptors, markers, daq, stash); also `load_stash`, `load_mat_with_objects`, `amplitude_spectrum`, `dominant_frequency`. CLI: `python ieapp_mat.py file.mat` |
| `read_measurement.py` | Inspect one file, plot one waveform + spectrum (`--plot`), export the label table (`--csv`) |
| `batch_to_dataframe.py` | Folder → one pandas DataFrame (labels, peak amplitude, dominant frequency); `--out`, `--waveforms` |
| `requirements.txt` | `numpy`, `scipy` required; `pandas`, `pyarrow`, `matplotlib` optional |

```bash
pip install -r requirements.txt
python ieapp_mat.py /path/to/measurement.mat
python read_measurement.py /path/to/measurement.mat --plot signal.png
python batch_to_dataframe.py /path/to/folder --out all.pkl
```

Why a custom reader: `scipy.io.loadmat` returns MATLAB `table`/`datetime`/`categorical`/`string` objects
only as `MatlabOpaque` placeholders. `ieapp_mat.py` decodes the MCOS object block
(`__function_workspace__`) that holds their contents. Verified against MATLAB R2024a; works with scipy 1.16 and 1.18.
