#!/bin/bash
# ---------------------------------------------------------------------
# SLURM DIRECTIVES for AddOrReplaceReadGroups
# ---------------------------------------------------------------------
#SBATCH --account=def-saitken
#SBATCH --job-name=add_read_groups
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --time=01:00:00
#SBATCH --array=0-107 # Adjust array size if needed
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rafael.ribeiro@ubc.ca
#SBATCH --output=%x_%A_%a.out
#SBATCH --error=%x_%A_%a.err

# ---------------------------------------------------------------------
# ENVIRONMENT & PATHS SETUP
# ---------------------------------------------------------------------

module load StdEnv/2023
module load gatk/4.6.1.0
module load samtools/1.22.1

# Define core paths
export TOP_DIR=/home/rafaubc/scratch/rafaubc/DF_ref_genome_unedited
# Directory containing your *deduplicated* BAM files
export DEDUP_BAM_DIR="${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/BAM_files/deduplicated"
# Output directory for the final RG-tagged BAM files
export RG_BAM_DIR="${DEDUP_BAM_DIR}/rg_tagged"
export SAMPLE_LIST=${TOP_DIR}/../Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/sample_ids_only.txt

# Create output directory
mkdir -p "$RG_BAM_DIR"

# ---------------------------------------------------------------------
# JOB EXECUTION
# ---------------------------------------------------------------------

# 1. Get the current sample ACC
TASK_ID=$((SLURM_ARRAY_TASK_ID + 1))
ACC=$(cat "$SAMPLE_LIST" | sed -n "${TASK_ID}p")

if [ -z "$ACC" ]; then
    echo "ERROR: Could not retrieve Sample ID for Task ID $SLURM_ARRAY_TASK_ID. Exiting."
    exit 1
fi

echo "--- Processing Sample: $ACC (Task ID: $SLURM_ARRAY_TASK_ID) ---"

INPUT_BAM="$DEDUP_BAM_DIR/${ACC}_paired.dedup.bam"
OUTPUT_BAM="$RG_BAM_DIR/${ACC}_paired.dedup.rg.bam"

if [ ! -f "$INPUT_BAM" ]; then
    echo "ERROR: Deduplicated BAM not found: $INPUT_BAM. Skipping."
    exit 1
fi

# 2. Run GATK AddOrReplaceReadGroups
echo "Adding Read Groups to $ACC..."

# Use the sample accession name for both RGID and RGSM, as recommended
gatk AddOrReplaceReadGroups \
    -I "$INPUT_BAM" \
    -O "$OUTPUT_BAM" \
    --RGID "$ACC" \
    --RGLB GBS_Lib \
    --RGPL ILLUMINA \
    --RGPU SeqUnit \
    --RGSM "$ACC" \
    --SORT_ORDER coordinate

if [ $? -ne 0 ]; then
    echo "ERROR: GATK AddOrReplaceReadGroups failed for $ACC."
    exit 1
fi

# 3. Index the final BAM (Required for HaplotypeCaller)
echo "Indexing final BAM file..."

# Use samtools index -c for CSI index needed for large genomes
samtools index -c -@ $SLURM_CPUS_PER_TASK "$OUTPUT_BAM"

if [ $? -ne 0 ]; then
    echo "ERROR: Samtools index failed for $ACC."
    exit 1
fi

echo "RG tagging and indexing complete for $ACC. Final file: $OUTPUT_BAM"
