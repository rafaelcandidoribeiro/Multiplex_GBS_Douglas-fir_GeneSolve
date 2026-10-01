#!/bin/bash
#SBATCH --account=def-saitken      # Compute Canada account
#SBATCH --time=20:00:00           # Time limit (4 hours recommended for this)
#SBATCH --cpus-per-task=16         # Number of CPU cores to use
#SBATCH --mem=124G                 # Job memory (Adjust based on genome size/coverage)
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rafael.ribeiro@ubc.ca
#SBATCH --output=%x_%A_%a.out
#SBATCH --error=%x_%A_%a.err

# --- 1. Define Paths and Variables ---

# Path to your reference genome FASTA file (MANDATORY)
# Make sure this file is indexed (index file: <REF>.fai must exist)
REFERENCE="/home/rafaubc/scratch/rafaubc/DF_ref_genome_unedited/interior_primary_mancur.fa"

# Directory where your BAM files are located (Assuming they are indexed: <BAM>.bai must exist)
DEDUP_BAM_DIR="/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/BAM_files/deduplicated/rg_tagged/"

# Output directory for the final VCF
OUTPUT_DIR="/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/SNP_calling/final_vcf_samtools"
FINAL_VCF="${OUTPUT_DIR}/DF_GBS_Genome_Wide_demux_py_BCFtools.vcf.gz"

# Define the temporary file for the BAM list
BAM_LIST_FILE="${OUTPUT_DIR}/bam_list.txt"

# --- 2. Setup Environment ---
module load samtools/1.22 
module load bcftools/1.22 
mkdir -p "$OUTPUT_DIR"

# --- 3. Create BAM File List ---

# Find all BAM files and write their paths, one per line, to the list file.
find "$DEDUP_BAM_DIR" -name "*.dedup.rg.bam" > "$BAM_LIST_FILE"

FILE_COUNT=$(wc -l < "$BAM_LIST_FILE")

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "🚨 ERROR: No *.dedup.rg.bam files found. Exiting."
    exit 1
fi

echo "Found $FILE_COUNT deduplicated, RG-tagged BAM files for calling. Listing in $BAM_LIST_FILE"

# --- 4. Run BCFtools Pipeline ---
echo "Starting variant calling using bcftools mpileup and bcftools call..."

# bcftools mpileup: Reads the BAM paths from the list file using -b
bcftools mpileup -b "$BAM_LIST_FILE" -f "$REFERENCE" -q 20 -Q 10 -a DP,AD -O u -o - --threads "$SLURM_CPUS_PER_TASK" | \
# bcftools call: Performs the statistical variant calling on the BCF stream
bcftools call \
    -m \
    -v \
    -O z \
    -o "$FINAL_VCF"

# --- 5. Index the Final VCF ---
echo "Indexing the final VCF file..."
bcftools index -f "$FINAL_VCF"

# Clean up the temporary BAM list file
rm "$BAM_LIST_FILE"

echo "✅ Script finished. Final VCF is located at: $FINAL_VCF"
