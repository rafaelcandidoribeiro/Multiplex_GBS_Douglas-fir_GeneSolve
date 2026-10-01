#!/bin/bash
# ---------------------------------------------------------------------
# SLURM DIRECTIVES for JOB ARRAY (Sorting)
# ---------------------------------------------------------------------
#SBATCH --account=def-saitken       # Replace with your Compute Canada account name (e.g., def-someuser)
# Set the job name
#SBATCH --job-name=samtools_sort
# Use 1 core per job, but request 8 threads for Samtools sorting
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
# Sorting is memory-intensive. Request 12GB/core (total 96GB) to be safe.
#SBATCH --mem-per-cpu=14G
# Set the time limit (1 hour per sample should be plenty)
#SBATCH --time=01:00:00
# Define the job array range (108 samples means 0-107)
#SBATCH --array=0-107
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rafael.ribeiro@ubc.ca
# Output and error files
#SBATCH --output=%x_%A_%a.out
#SBATCH --error=%x_%A_%a.err


# ---------------------------------------------------------------------
# ENVIRONMENT SETUP
# ---------------------------------------------------------------------

module load StdEnv/2023
module load samtools/1.18 # Samtools is required for sorting and indexing

# Define paths (reuse paths from mapping script)
export TOP_DIR=/home/rafaubc/scratch/rafaubc/DF_ref_genome_unedited
# Location where the *unsorted* BAM files are saved
export BAM_DIR=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/BAM_files
# The final output directory for sorted BAMs (Can be the same as BAM_DIR)
export OUT_DIR=${BAM_DIR}
export SAMPLE_LIST=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/sample_ids_only.txt

# Create the final output directory if it doesn't exist
mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------------
# JOB EXECUTION (Running in $SLURM_TMPDIR)
# ---------------------------------------------------------------------

echo "Starting Samtools coordinate sorting..."

# 1. Get the sample ID corresponding to the current Array Task ID
TASK_ID=$((SLURM_ARRAY_TASK_ID + 1))
ACC=$(cat "$SAMPLE_LIST" | sed -n "${TASK_ID}p")

if [ -z "$ACC" ]; then
    echo "ERROR: Could not retrieve Sample ID for Task ID $SLURM_ARRAY_TASK_ID. Exiting."
    exit 1
fi

echo "--- Processing Sample: $ACC (Array Task ID: $SLURM_ARRAY_TASK_ID) ---"

# Define filenames
INPUT_BAM="$BAM_DIR/${ACC}_paired.bam"
# Define the final output file name
OUTPUT_SORTED_BAM="$OUT_DIR/${ACC}_paired.sorted.bam"

# Check if input BAM exists
if [ ! -f "$INPUT_BAM" ]; then
    echo "ERROR: Input BAM file not found: $INPUT_BAM. Skipping."
    exit 1
fi

# 2. Copy the BAM file to scratch for faster sorting
TEMP_BAM="$SLURM_TMPDIR/${ACC}_paired.bam"
TEMP_SORTED_BAM="$SLURM_TMPDIR/${ACC}_paired.sorted.bam"

echo "Copying $INPUT_BAM to scratch..."
cp "$INPUT_BAM" "$SLURM_TMPDIR/"

# 3. Sort reads by coordinate using Samtools
echo "Starting coordinate sorting with Samtools..."
# -@ $SLURM_CPUS_PER_TASK uses 8 threads
# -o specifies the output file (in scratch)
samtools sort -@ $SLURM_CPUS_PER_TASK -o "$TEMP_SORTED_BAM" "$TEMP_BAM"

if [ $? -ne 0 ]; then
    echo "ERROR: Samtools sort failed for $ACC."
    exit 1
fi

# 4. Index the sorted BAM file
echo "Creating BAM index (.csi) file..."
# Samtools index must be run on a coordinate-sorted BAM
samtools index -c -@ $SLURM_CPUS_PER_TASK "$TEMP_SORTED_BAM"


if [ $? -ne 0 ]; then
    echo "ERROR: Samtools index failed for $ACC."
    exit 1
fi

# 5. Copy the final sorted BAM and its index back to the project space
echo "Copying final sorted BAM and index back to $OUT_DIR..."
cp "$TEMP_SORTED_BAM" "$OUTPUT_SORTED_BAM"
cp "$TEMP_SORTED_BAM".csi "$OUTPUT_SORTED_BAM".csi # given the size of the scafolds, indexing the sorted bam files will generate .csi files instead of .bai
cp "$TEMP_SORTED_BAM".bai "$OUTPUT_SORTED_BAM".bai  # given the size of the scafolds, indexing the sorted bam files will generate .csi files instead of .bai

# 6. Clean up scratch space
rm "$TEMP_BAM" "$TEMP_SORTED_BAM" "$TEMP_SORTED_BAM".csi "$TEMP_SORTED_BAM".bai

echo "Successfully sorted and indexed $ACC. Final file: $OUTPUT_SORTED_BAM"
