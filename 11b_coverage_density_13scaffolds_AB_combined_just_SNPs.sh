#!/bin/bash
#SBATCH --job-name=SNP_Only
#SBATCH --account=def-saitken
#SBATCH --time=04:00:00
#SBATCH --mem=12G
#SBATCH --array=0-59
#SBATCH --output=snps_%a.out

module load bcftools/1.22

VCF="/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/combined_replicates/mapped_to_13_scaffolds_only/SNP_calling/final_vcf_samtools/DF_GBS_Genome_Wide_demux_py_BCFtools_only13_scaffolds_AB_combined.vcf.gz"
BAM_DIR="/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/combined_replicates/mapped_to_13_scaffolds_only/BAM_files"
OUT_DIR="${BAM_DIR}/audit_snps_only"
SAMPLE_LIST="/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/combined_replicates/sample_ids_combined.txt"

mkdir -p "$OUT_DIR"

# 1. Isolate the specific sample name for this task
TASK_ID=$((SLURM_ARRAY_TASK_ID + 1))
RAW_ACC=$(sed -n "${TASK_ID}p" "$SAMPLE_LIST" | tr -d '\r' | xargs)

# 2. Create a temporary 1-sample file (This mimics your working script's logic)
TMP_SFILE="${OUT_DIR}/tmp_${RAW_ACC}.txt"
echo "$RAW_ACC" > "$TMP_SFILE"

# 3. Run the query using -S (The Uppercase flag)
# This will output: CHROM  POS  DP
bcftools query -S "$TMP_SFILE" -f '%CHROM\t%POS\t[%DP]\n' "$VCF" | \
awk -v w=500000 'BEGIN {OFS="\t"} 
{
    bin = int($2/w)*w;
    key = $1 "_" bin;
    count[key]++; 
    if($3 > 2) d2[key]++; 
    if($3 > 4) d4[key]++;
} 
END {
    # Print the windowed results
    for (k in count) print k, count[k], (d2[k]?d2[k]:0), (d4[k]?d4[k]:0)
}' > "${OUT_DIR}/${RAW_ACC}.snps.txt"

# Clean up the temp file
rm "$TMP_SFILE"
