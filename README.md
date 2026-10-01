# Multiplex GBS Pipeline — Douglas-fir (GeneSolve)

An end-to-end bioinformatics workflow for processing, demultiplexing, mapping, variant calling, and windowed coverage/SNP auditing for Douglas-fir (*Pseudotsuga menziesii*) Genotyping-by-Sequencing (GBS).

---

## Pipeline Workflow

The pipeline should be run sequentially from raw sequence data processing down to genomic window audits. Below is the breakdown of each script included in the repository and its role in the workflow.

| Step | Script Name | Description & Purpose |
| :--- | :--- | :--- |
| **01a / 01b** | `01a_demux_python_script.py`<br>`01b_Slurm_submit_demux.sh` | **Demultiplexing:** Validates Read 1 for inline sample barcodes + *PstI* site (`TGCAG`) and Read 2 for *MspI* cutsite remnants (`NNNNNNNCGG`) using a custom Python wrapper executed via SLURM. |
| **02** | `02_trim_2_demux_py.sh` | **Quality & Adapter Trimming:** Runs Trimmomatic to strip Illumina adapters, low-quality bases, and short fragments from paired-end reads. |
| **03** | `03_Mapping_bwa_script_demux_py.sh` | **Reference Mapping:** Maps clean reads against the Douglas-fir reference genome using BWA-MEM within a SLURM job array. |
| **04** | `04_samtools_sort_demux_py.sh` | **Coordinate Sorting & Indexing:** Sorts alignment files by genomic coordinate and generates spatial `.csi` indexes using Samtools. |
| **05** | `05_flagstat_report.sh` | **Alignment QC (Flagstat):** Generates overall mapping statistics and alignment flags per sample. |
| **06** | `06_idxstats_report.sh` | **Alignment QC (Idxstats):** Extracts read counts mapped per scaffold to evaluate genomic distribution. |
| **07** | `07_mark_duplicates_demux_py.sh` | **Duplicate Marking:** Uses Picard MarkDuplicates to identify and flag PCR duplicates across sorted BAMs. |
| **08** | `08_add_read_groups_GATK_step2_demux_py.sh` | **Read Group Assignment:** Injects standard `@RG` headers into BAM files to prepare them for downstream GATK and population tools. |
| **09** | `09_BCF_tools_SNP_caller_demux_py.sh` | **Variant Calling:** Performs multi-sample SNP calling using BCFtools. |
| **10** | `10_count_depth_miss_30_50_80_DP_4_and_2_subset_list.sh` | **VCF Yield & Missingness Audit:** Evaluates SNP retention rates across missingness thresholds (30%, 50%, 80%) and depth filters (`DP >= 2` and `DP >= 4`) for a target sample list. |
| **11a** | `11a_coverage_density_13scaffolds_AB_combined_just_reads.sh` | **Window Read Depth Audit:** Computes average read depth across 500 kbp genomic windows for each sample. |
| **11b** | `11b_coverage_density_13scaffolds_AB_combined_just_SNPs.sh` | **Window SNP Density Audit:** Computes SNP counts across 500 kbp genomic windows (excluding windows with zero SNPs). |
| **11c** | `11c_merge_audit_depth_and_SNPs.sh` | **Master Audit Integration:** Merges individual window read depth and SNP density files into unified master audit tables. |

---
