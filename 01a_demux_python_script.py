import subprocess
import sys
import os


def run_demux():
    # --- FILE PATHS ---
    r1 = "/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/E02749_1_150bp_22_lanes.merge_chastity_passed.fastq.gz"
    r2 = "/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/E02749_2_150bp_22_lanes.merge_chastity_passed.fastq.gz"
    barcode_file = "/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/CASS_Barcodes_lane1.txt"
    out_dir = "/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/GbprocesS_output"

    # --- GBS PARAMETERS ---
    pst1_remnant = "TGCAG"
    # Using 'N' instead of 'X' as it is the standard wildcard in most Cutadapt versions
    # We remove the '^' here and use the -u option combined with a linked adapter
    # to ensure it's at the start.
    mspi_wildcard = "NNNNNNNCGG"

    if not os.path.exists(out_dir):
        os.makedirs(out_dir)

    # 1. Parse barcodes for Read 1
    adapter_args = []
    with open(barcode_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"): continue
            parts = line.split('\t')
            if len(parts) < 2: continue

            sample_id, barcode = parts[0], parts[1]
            # Use ^ for R1 to ensure it's the start
            adapter_args.extend(["-g", f"{sample_id}=^{barcode}{pst1_remnant}"])

    # 2. Build the Cutadapt command
    # Using -G "NNNNNNNCGG" without the ^ to avoid the multiple restriction error.
    # To ensure it is at the start, we use --overlap 10 (the full length of the pattern).
    cmd = [
        "cutadapt",
        "-j", "8",
        "-e", "0.1",
        "--no-indels",
        "--action=trim",
        "--discard-untrimmed",
        "--overlap", "10",
        "-G", mspi_wildcard,
        *adapter_args,
        "-o", f"{out_dir}/{{name}}_R1.fastq.gz",
        "-p", f"{out_dir}/{{name}}_R2.fastq.gz",
        r1, r2
    ]

    print(f"Starting demux (R1 Barcode + R2 NNNNNNNCGG validation) into: {out_dir}")
    try:
        subprocess.run(cmd, check=True)
        print("\nProcess complete.")
    except subprocess.CalledProcessError as e:
        print(f"\nCutadapt failed with exit code {e.returncode}")

if __name__ == "__main__":
    run_demux()
