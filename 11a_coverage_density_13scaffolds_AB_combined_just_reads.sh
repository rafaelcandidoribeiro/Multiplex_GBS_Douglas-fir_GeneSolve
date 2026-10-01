#!/bin/bash
#SBATCH --job-name=Depth_Only
#SBATCH --account=def-saitken
#SBATCH --time=03:00:00
#SBATCH --mem=8G
#SBATCH --array=0-59
#SBATCH --output=depth_%a.out

module load samtools/1.20

BAM_DIR="/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/combined_replicates/mapped_to_13_scaffolds_only/BAM_files"
OUT_DIR="${BAM_DIR}/audit_depth_only"
SAMPLE_LIST="/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/combined_replicates/sample_ids_combined.txt"
SCAFF_BED="/home/rafaubc/scratch/rafaubc/scripts/scaffolds.bed"

mkdir -p "$OUT_DIR"

TASK_ID=$((SLURM_ARRAY_TASK_ID + 1))
RAW_ACC=$(sed -n "${TASK_ID}p" "$SAMPLE_LIST" | tr -d '\r' | xargs)
BAM="${BAM_DIR}/${RAW_ACC}_paired.sorted.bam"

# Generate 500kb windows from your scaffolds
# Then run bedcov and calculate mean depth (sum_depth / window_size)
awk -v w=500000 'BEGIN {OFS="\t"} {for(i=$2; i<$3; i+=w) print $1, i, (i+w>$3?$3:i+w)}' "$SCAFF_BED" | \
samtools bedcov /dev/stdin "$BAM" | \
awk -v w=500000 'BEGIN {OFS="\t"} {print $1, $2, $3, $4/w}' > "${OUT_DIR}/${RAW_ACC}.depth.bed"
