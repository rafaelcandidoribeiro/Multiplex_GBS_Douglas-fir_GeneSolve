#!/bin/bash
# ---------------------------------------------------------------------
# SLURM DIRECTIVES for JOB ARRAY
# ---------------------------------------------------------------------
#SBATCH --account=def-saitken       # Replace with your Compute Canada account name (e.g., def-someuser)
# Set the job name, will appear as bwa_array_12345_[0-107]
#SBATCH --job-name=bwa_array_map
# Request a single CPU core (since each job only processes one sample)
#SBATCH --ntasks=1
# Request 8 CPU cores per task for BWA-MEM2
#SBATCH --cpus-per-task=12
# Use 5 GB of memory per CPU core (total 40 GB)
#SBATCH --mem-per-cpu=10G
# Set the time limit (Mapping a single sample is faster)
#SBATCH --time=02:00:00
# Define the job array range: 0 to N-1 (108 samples means 0-107)
#SBATCH --array=0-107
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rafael.ribeiro@ubc.ca
# Standard output and error files will include the Array ID
#SBATCH --output=%x_%A_%a.out
#SBATCH --error=%x_%A_%a.err


# ---------------------------------------------------------------------
# USER DEFINED PATHS AND MODULES
# ---------------------------------------------------------------------

# Load standard environment and required modules (BWA and Samtools)
module load StdEnv/2023
module load bwa/0.7.17 # NOTE: BWA 0.7.17 is older. If bwa-mem2 is available, use that for better performance.
module load samtools/1.18

# Define paths (as requested)
# The parent project directory
export TOP_DIR=/home/rafaubc/scratch/rafaubc/DF_ref_genome_unedited
# The final output directory for BAM files
export OUT_DIR=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/BAM_files/
# The reference genome location (must be indexed beforehand)
export REFERENCE_GENOME=${TOP_DIR}/interior_primary_mancur.fa.gz

# Assuming your trimmed files are located in a folder named 'Trimming'
# relative to your BWA script, or a specific path on your project space:
export TRIM_DIR=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc
# Ensure the sample list file is in the submission directory
export SAMPLE_LIST=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/sample_ids_only.txt

# Create the final output directory if it doesn't exist
mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------------
# JOB EXECUTION (Running in $SLURM_TMPDIR)
# ---------------------------------------------------------------------

echo "Starting BWA Mapping for selected subset..."
echo "Running on $(hostname) within $SLURM_TMPDIR"

# 1. Get the sample ID corresponding to the current Array Task ID
TASK_ID=$((SLURM_ARRAY_TASK_ID + 1))
ACC=$(cat "$SAMPLE_LIST" | sed -n "${TASK_ID}p")

if [ -z "$ACC" ]; then
    echo "ERROR: Could not retrieve Sample ID for Task ID $SLURM_ARRAY_TASK_ID. Exiting."
    exit 1
fi

echo "--- Processing Sample: $ACC (Array Task ID: $SLURM_ARRAY_TASK_ID) ---"

# 2. Define Input/Output filenames and copy files to scratch ($SLURM_TMPDIR)
IN_R1_NAME="${ACC}_trim_R1_paired.fastq.gz"
IN_R2_NAME="${ACC}_trim_R2_paired.fastq.gz"
REF_NAME=$(basename "$REFERENCE_GENOME")

# Define temporary scratch files
TEMP_R1="$SLURM_TMPDIR/$IN_R1_NAME"
TEMP_R2="$SLURM_TMPDIR/$IN_R2_NAME"
TEMP_REF="$SLURM_TMPDIR/$REF_NAME"
OUT_SAM="$SLURM_TMPDIR/${ACC}_paired.sam"
FINAL_BAM="$OUT_DIR/${ACC}_paired.bam"

# Copy the FASTQ files to scratch for faster access
cp "$TRIM_DIR/$IN_R1_NAME" "$SLURM_TMPDIR/"
cp "$TRIM_DIR/$IN_R2_NAME" "$SLURM_TMPDIR/"
# Copy the reference genome and its index files (crucial for BWA) to scratch
cp "$REFERENCE_GENOME"* "$SLURM_TMPDIR/"

# 3. BWA Mapping (using the faster $SLURM_TMPDIR paths)
echo "Starting alignment..."
bwa mem -t $SLURM_CPUS_PER_TASK "$TEMP_REF" "$TEMP_R1" "$TEMP_R2" > "$OUT_SAM"

if [ $? -eq 0 ]; then
    echo "BWA Mapping completed successfully for $ACC."

    # 4. Convert SAM to sorted BAM
    # Use samtools view to convert, and pipe (|) to samtools sort to sort directly.
    samtools view -@ $SLURM_CPUS_PER_TASK -bS "$OUT_SAM" | samtools sort -@ $SLURM_CPUS_PER_TASK -o "$SLURM_TMPDIR/${ACC}_paired.bam" -

    if [ $? -eq 0 ]; then
        echo "SAM converted and sorted to BAM successfully for $ACC."

        # 5. Copy final result back to project space
        cp "$SLURM_TMPDIR/${ACC}_paired.bam" "$FINAL_BAM"

        # 6. Clean up scratch space
        rm "$OUT_SAM" "$TEMP_R1" "$TEMP_R2" "$SLURM_TMPDIR/${ACC}_paired.bam"

        echo "Final BAM file saved to: $FINAL_BAM"
    else
        echo "ERROR: Samtools failed for $ACC."
    fi
else
    echo "ERROR: BWA-MEM failed for $ACC."
fi

echo "Job finished for $ACC."
