#!/bin/bash
# Run this where your folders are
DEPTH_DIR="./audit_depth_only"
SNP_DIR="./audit_snps_only"
FINAL_DIR="./master_audit_final"
mkdir -p "$FINAL_DIR"

# Loop through all depth files
for d_file in ${DEPTH_DIR}/*.depth.bed; do
    # Get the sample name (e.g., 23_13A_and_B_combined)
    base=$(basename "$d_file" .depth.bed)
    s_file="${SNP_DIR}/${base}.snps.txt"

    if [ -f "$s_file" ]; then
        echo "Merging $base..."

        # AWK Logic:
        # 1. Load the SNP file into memory first (NR==FNR)
        # 2. Read the Depth file line-by-line
        # 3. Create a key and check if it exists in the SNP memory
        awk 'BEGIN {OFS="\t"}
            NR==FNR {
                # Split key like HiC_scaffold_1_500000 into separate parts if needed
                # But here we just store the whole key as the index
                total[$1]=$2; d2[$1]=$3; d4[$1]=$4; next
            }
            {
                # Create the matching key from the Depth file columns
                key = $1 "_" $2;

                # Print: Chr, Start, End, Depth, TotalSNPs, SNPs>2, SNPs>4, SampleID
                print $1, $2, $3, $4, \
                      (total[key] ? total[key] : 0), \
                      (d2[key] ? d2[key] : 0), \
                      (d4[key] ? d4[key] : 0), \
                      "'"$base"'"
            }' "$s_file" "$d_file" > "${FINAL_DIR}/${base}_final_audit.bed"
    fi
done

echo "Done! Check ${FINAL_DIR}"
