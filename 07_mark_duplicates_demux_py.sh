#!/bin/bash
# ---------------------------------------------------------------------
# SLURM DIRECTIVES for JOB ARRAY (MarkDuplicates)
# ---------------------------------------------------------------------
#SBATCH --account=def-saitken
# Set the job name
#SBATCH --job-name=mark_duplicates
# Request 1 CPU core per job, but allocate 8 threads for Picard (for sorting/merging)
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
# MarkDuplicates is RAM-intensive. Request 10GB/core (80GB total) to avoid OOM.
#SBATCH --mem-per-cpu=14G
# Set a generous time limit for this intensive step
#SBATCH --time=06:00:00
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
module load java/21.0.1     # Load a suitable Java version
module load picard/3.1.0   # Load a suitable Picard version
module load samtools/1.18   # Required for indexing the final BAM

# Define paths
export TOP_DIR=/home/rafaubc/scratch/rafaubc/DF_ref_genome_unedited
# Directory containing your *sorted* BAM files
export INPUT_DIR=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/BAM_files
# Output directory for the final, cleaned BAMs (can be the same)
export OUTPUT_DIR=${INPUT_DIR}/deduplicated
export SAMPLE_LIST=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/sample_ids_only.txt

# Create the final output directory
mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------
# JOB EXECUTION (Using $SLURM_TMPDIR for I/O)
# ---------------------------------------------------------------------

echo "Starting MarkDuplicates process..."

# 1. Get the sample ID
TASK_ID=$((SLURM_ARRAY_TASK_ID + 1))
ACC=$(cat "$SAMPLE_LIST" | sed -n "${TASK_ID}p")

if [ -z "$ACC" ]; then
    echo "ERROR: Could not retrieve Sample ID for Task ID $SLURM_ARRAY_TASK_ID. Exiting."
    exit 1
fi

echo "--- Processing Sample: $ACC (Array Task ID: $SLURM_ARRAY_TASK_ID) ---"

# Define filenames
INPUT_BAM="$INPUT_DIR/${ACC}_paired.sorted.bam"
OUTPUT_DEDUP_BAM="$OUTPUT_DIR/${ACC}_paired.dedup.bam"
OUTPUT_METRICS="$OUTPUT_DIR/${ACC}_paired.dedup.metrics"

# Check if input BAM exists
if [ ! -f "$INPUT_BAM" ]; then
    echo "ERROR: Input sorted BAM file not found: $INPUT_BAM. Skipping."
    exit 1
fi

# 2. Copy Input to scratch for faster processing
TEMP_INPUT_BAM="$SLURM_TMPDIR/${ACC}_paired.sorted.bam"
TEMP_DEDUP_BAM="$SLURM_TMPDIR/${ACC}_paired.dedup.bam"
echo "Copying $INPUT_BAM to scratch..."
cp "$INPUT_BAM" "$SLURM_TMPDIR/"

# Copy the index file as well (required for Picard/Samtools to read the BAM efficiently)
# We assume the index is .bai (CSI formatted) as per the fix in samtools_sort.sh
if [ -f "$INPUT_BAM".bai ]; then
    cp "$INPUT_BAM".bai "$SLURM_TMPDIR/"
elif [ -f "$INPUT_BAM".csi ]; then
    cp "$INPUT_BAM".csi "$SLURM_TMPDIR/"
else
    echo "ERROR: Index file (.bai or .csi) not found in scratch after indexing."
    exit 1
fi

# 3. Run Picard MarkDuplicates
echo "Starting MarkDuplicates..."
# MAX_RECORDS_IN_RAM is set to 2500000 to manage large data volumes
# USE_FAST_AGGLOMERATIVE_CLUSTERING=true speeds up the clustering of reads
java -jar $EBROOTPICARD/picard.jar MarkDuplicates \
    I="$TEMP_INPUT_BAM" \
    O="$TEMP_DEDUP_BAM" \
    M="$OUTPUT_METRICS" \
    MAX_RECORDS_IN_RAM=2500000 \
    VALIDATION_STRINGENCY=LENIENT \
    REMOVE_DUPLICATES=false # We mark them, but do NOT remove them yet (best practice)

if [ $? -ne 0 ]; then
    echo "ERROR: Picard MarkDuplicates failed for $ACC."
    exit 1
fi

# 4. Index the new deduplicated BAM file
echo "Indexing deduplicated BAM file..."
# Use samtools with the CSI flag (-c) for large scaffolds
samtools index -c -@ $SLURM_CPUS_PER_TASK "$TEMP_DEDUP_BAM"

if [ $? -ne 0 ]; then
    echo "ERROR: Samtools index failed for $ACC."
    exit 1
fi

# 5. Copy the final deduplicated BAM and its index back to the project space
echo "Copying final files back to $OUTPUT_DIR..."
# Copy the main BAM file
cp "$TEMP_DEDUP_BAM" "$OUTPUT_DEDUP_BAM"

# Copy the index file (check for .bai first, then .csi)
if [ -f "$TEMP_DEDUP_BAM".bai ]; then
    cp "$TEMP_DEDUP_BAM".bai "$OUTPUT_DEDUP_BAM".bai
    INDEX_EXT=".bai"
elif [ -f "$TEMP_DEDUP_BAM".csi ]; then
    cp "$TEMP_DEDUP_BAM".csi "$OUTPUT_DEDUP_BAM".csi
    INDEX_EXT=".csi"
else
    echo "ERROR: Index file (.bai or .csi) not found in scratch after indexing."
    exit 1
fi

# 6. Clean up scratch space
# Use the found extension for cleanup
if [ -f "$TEMP_DEDUP_BAM".bai ]; then
    rm "$TEMP_INPUT_BAM" "$TEMP_INPUT_BAM".bai "$TEMP_DEDUP_BAM" "$TEMP_DEDUP_BAM"$INDEX_EXT
elif [ -f "$TEMP_DEDUP_BAM".csi ]; then
    rm "$TEMP_INPUT_BAM" "$TEMP_INPUT_BAM".csi "$TEMP_DEDUP_BAM" "$TEMP_DEDUP_BAM"$INDEX_EXT
else
    echo "ERROR: Index file (.bai or .csi) not found in scratch. Could not clean up scratch"
    exit 1
fi
