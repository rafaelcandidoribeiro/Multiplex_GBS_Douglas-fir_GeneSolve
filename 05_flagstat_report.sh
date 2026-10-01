#!/bin/bash
# ---------------------------------------------------------------------
# SLURM DIRECTIVES for JOB ARRAY (Flagstat)
# ---------------------------------------------------------------------
#SBATCH --account=def-saitken
# Set the job name
#SBATCH --job-name=samtools_flagstat
# Flagstat is very fast and requires minimal resources
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
# Request minimal memory (1 GB is more than enough for flagstat)
#SBATCH --mem-per-cpu=1G
# Set a short time limit
#SBATCH --time=00:10:00
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
module load samtools/1.18

# Define paths (based on your sorted BAM location)
export TOP_DIR=/home/rafaubc/projects/def-saitken/rafaubc/DF_ref_genome_unedited
# This is the directory containing your final *sorted* BAM files
export BAM_DIR=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp/trim_retry_2/paired_fastqc/BAM_files
# Location of the sample list
export SAMPLE_LIST=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp/trim_retry_2/paired_fastqc/sample_ids.txt


# ---------------------------------------------------------------------
# JOB EXECUTION
# ---------------------------------------------------------------------

echo "Starting Samtools flagstat report generation..."

# 1. Get the sample ID corresponding to the current Array Task ID
TASK_ID=$((SLURM_ARRAY_TASK_ID + 1))
ACC=$(cat "$SAMPLE_LIST" | sed -n "${TASK_ID}p")

if [ -z "$ACC" ]; then
    echo "ERROR: Could not retrieve Sample ID for Task ID $SLURM_ARRAY_TASK_ID. Exiting."
    exit 1
fi

echo "--- Processing Sample: $ACC (Array Task ID: $SLURM_ARRAY_TASK_ID) ---"

# Define the input BAM and output report names
INPUT_BAM="$BAM_DIR/${ACC}_paired.sorted.bam"
OUTPUT_REPORT="$BAM_DIR/${ACC}_paired.sorted.flagstat.txt"

# Check if the coordinate-sorted BAM and its index exist
if [ ! -f "$INPUT_BAM" ]; then
    echo "ERROR: Sorted BAM file not found: $INPUT_BAM. Skipping."
    exit 1
fi
# The index file is required for flagstat to run efficiently
if [ ! -f "$INPUT_BAM".bai ] && [ ! -f "$INPUT_BAM".csi ]; then
    echo "WARNING: BAM Index file (.bai or .csi) not found for $ACC. Flagstat may fail or be slow. Skipping."
    exit 1
fi

# 2. Run samtools flagstat
# We run this directly on the project space, as it's primarily I/O reading,
# and the scratch space overhead is not worth the minimal speed gain.

echo "Running flagstat on $INPUT_BAM..."
# Flagstat reads the BAM and prints statistics, which we redirect (>) to the report file
samtools flagstat "$INPUT_BAM" > "$OUTPUT_REPORT"

if [ $? -eq 0 ]; then
    echo "Flagstat report successfully created at: $OUTPUT_REPORT"
else
    echo "ERROR: samtools flagstat failed for $ACC."
    exit 1
fi

echo "Job finished for $ACC."
