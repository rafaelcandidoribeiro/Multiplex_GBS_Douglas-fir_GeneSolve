#!/bin/bash
# Remember to first run this chmod +x count_depth_miss_30_50_80_DP_4_and_2_subset_list.sh
# To "unlock" the script, then, run
# ./count_depth_miss_30_50_80_DP_4_and_2_subset_list.sh /home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/mapped_to_13_scaffolds_only/SNP_calling/final_vcf_samtools/DF_GBS_Genome_Wide_demux_py_BCFtools_only13_scaffolds.vcf.gz /home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve/Plate1_E02749/150bp_B/150bp/trim_retry_2_demux_py/paired_fastqc/sample_ids_only.txt




module load bcftools

VCF=$1
SAMPLE_FILE=$2

# Check for both arguments
if [ -z "$VCF" ] || [ -z "$SAMPLE_FILE" ]; then
    echo "Usage: ./qc_overlap_comprehensive.sh file.vcf.gz target_samples.txt"
    exit 1
fi

if [ ! -f "$SAMPLE_FILE" ]; then
    echo "ERROR: Sample list file '$SAMPLE_FILE' not found."
    exit 1
fi

# Thresholds
MIN_SNPS=50
# Note: We now check both DP > 2 and DP > 4

# Convert sample file to a comma-separated string for bcftools
TARGET_SAMPLES=$(paste -sd "," "$SAMPLE_FILE")

echo "-------------------------------------------------------"
echo "STAGE 1: Per-Sample Depth Audit"
echo "Targeting samples from: $SAMPLE_FILE"
echo "-------------------------------------------------------"
echo -e "Sample_Name\tSNPs_DP>2\tSNPs_DP>4"

# 1. Get sample names and dual counts ONLY for the targeted subset
SAMPLE_NAMES=($(bcftools query -s "$TARGET_SAMPLES" -l "$VCF"))
COUNTS=($(bcftools query -s "$TARGET_SAMPLES" -f '[%DP\t]\n' "$VCF" | awk '
{
    for (i=1; i<=NF; i++) {
        if ($i > 2) count2[i]++
        if ($i > 4) count4[i]++
    }
}
END {
    for (i=1; i<=NF; i++) print (count2[i]?count2[i]:0) ":" (count4[i]?count4[i]:0)
}'))

# 2. Build the 'keep' list based on the stricter DP>4 threshold
KEEP_NAMES=""
NUM_KEPT=0
for i in "${!SAMPLE_NAMES[@]}"; do
    NAME=${SAMPLE_NAMES[$i]}
    # Split the counts back out
    C2=$(echo "${COUNTS[$i]}" | cut -d: -f1)
    C4=$(echo "${COUNTS[$i]}" | cut -d: -f2)

    echo -e "$NAME\t$C2\t$C4"

    if [ "$C4" -ge "$MIN_SNPS" ]; then
        KEEP_NAMES+="$NAME,"
        ((NUM_KEPT++))
    fi
done

KEEP_NAMES_LIST=${KEEP_NAMES%,*}

echo "-------------------------------------------------------"
echo "STAGE 2: Overlap Analysis (Quality Subset: $NUM_KEPT samples)"
echo "-------------------------------------------------------"

if [ "$NUM_KEPT" -eq 0 ]; then
    echo "Result: 0 quality samples found."
else
    # 3. Comprehensive overlap tiers
    bcftools query -s "$KEEP_NAMES_LIST" -f '[%DP\t]\n' "$VCF" | awk -v n="$NUM_KEPT" '
    BEGIN {
        t30 = n * 0.3; t50 = n * 0.5; t80 = n * 0.8; t100 = n
    }
    {
        p2=0; p4=0
        for (i=1; i<=NF; i++) {
            if ($i > 2) p2++
            if ($i > 4) p4++
        }
        # Stats for DP > 2
        if (p2 >= t30)  d2_30++
        if (p2 >= t50)  d2_50++
        if (p2 >= t80)  d2_80++
        if (p2 == t100) d2_100++

        # Stats for DP > 4
        if (p4 >= t30)  d4_30++
        if (p4 >= t50)  d4_50++
        if (p4 >= t80)  d4_80++
        if (p4 == t100) d4_100++
    }
    END {
        printf "%-15s | %-10s | %-10s\n", "Overlap Tier", "DP > 2", "DP > 4"
        printf "----------------------------------------------\n"
        printf "%-15s | %-10d | %-10d\n", "30% Overlap", d2_30, d4_30
        printf "%-15s | %-10d | %-10d\n", "50% Overlap", d2_50, d4_50
        printf "%-15s | %-10d | %-10d\n", "80% Overlap", d2_80, d4_80
        printf "%-15s | %-10d | %-10d\n", "100% Core", d2_100, d4_100
    }'
fi
