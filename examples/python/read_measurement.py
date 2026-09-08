#!/usr/bin/env python3
"""
Read one IEApp measurement file and show what is inside.

    python read_measurement.py path/to/measurement.mat            # summary + first signal
    python read_measurement.py measurement.mat --signal 5          # pick another signal (0-based)
    python read_measurement.py measurement.mat --plot out.png      # save time / spectrum plot
    python read_measurement.py measurement.mat --csv labels.csv    # export per-signal table (no waveforms)

Requires numpy + scipy (pandas for --csv, matplotlib for --plot).
"""
import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ieapp_mat import amplitude_spectrum, dominant_frequency, load_ieapp  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", help="IEApp *.mat measurement file")
    ap.add_argument("--signal", type=int, default=0, help="0-based row of SignalsTable to inspect")
    ap.add_argument("--plot", metavar="PNG", help="save waveform + spectrum figure to this file")
    ap.add_argument("--csv", metavar="CSV", help="write the per-signal table (metadata + labels) to CSV")
    args = ap.parse_args()

    meas = load_ieapp(args.file)
    print(meas.summary())

    # --- the two tables -------------------------------------------------
    print("\nSignalsTable columns :", meas.signals.names)
    print("DescTable columns    :", meas.descriptors.names)
    print("\nFirst rows (signals joined with their labels on ID):")
    for i in range(min(3, meas.n_signals)):
        row = meas.signals.row(i)
        labels = meas.descriptors.row(i) if meas.descriptors.nrows > i else {}
        labels = {k: (v.item() if hasattr(v, "item") else v) for k, v in labels.items() if k != "ID"}
        print(f"  ID={int(row['ID'])} time={row['Time']} samples={int(row['Samples'])} "
              f"fs={row['SamplingFrequency']:.0f} Hz labels={labels}")

    # --- one waveform ---------------------------------------------------
    i = args.signal
    if not 0 <= i < meas.n_signals:
        print(f"\nsignal index {i} out of range (0..{meas.n_signals - 1})")
        return 1
    t, y = meas.waveform(i)
    fs = float(meas.signals["SamplingFrequency"][i])
    f, amp = amplitude_spectrum(y, fs)
    fmax = meas.daq.get("MaxFreq") or fs / 2
    fdom, adom = dominant_frequency(f, amp, fmin=60, fmax=fmax)
    print(f"\nSignal #{i} (ID {int(meas.signals['ID'][i])}): {y.size} samples, "
          f"t = {t[0]:.4f} .. {t[-1]:.4f} s, peak |A| = {np.abs(y).max():.4f}, "
          f"dominant frequency ~ {fdom:.0f} Hz")

    if args.csv:
        df = meas.to_dataframe().drop(columns=["Signal"])
        df.to_csv(args.csv, index=False)
        print(f"wrote {args.csv} ({len(df)} rows)")

    if args.plot:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(9, 6), constrained_layout=True)
        ax1.plot(t, y, lw=0.7)
        ax1.axhline(meas.daq.get("TriggerLevel", 0), color="C3", ls="--", lw=0.8, label="trigger level")
        ax1.set(xlabel="time t [s] (0 = trigger)", ylabel="amplitude A [V]",
                title=f"{Path(args.file).name} - signal ID {int(meas.signals['ID'][i])}")
        ax1.legend(loc="upper right")
        sel = (f >= 60) & (f <= fmax)
        ax2.plot(f[sel], amp[sel], lw=0.8)
        if np.isfinite(fdom):
            ax2.plot(fdom, adom, "kv", label=f"dominant {fdom:.0f} Hz")
            ax2.legend(loc="upper right")
        ax2.set(xlabel="frequency f [Hz]", ylabel="amplitude A [V]", xlim=(60, fmax))
        fig.savefig(args.plot, dpi=130)
        print(f"wrote {args.plot}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
