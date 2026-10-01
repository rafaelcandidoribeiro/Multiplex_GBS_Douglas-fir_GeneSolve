#!/bin/bash
#SBATCH --job-name=trimmomatic
#SBATCH --account=def-saitken
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --time=0-12:00:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rafael.ribeiro@ubc.ca
#SBATCH -o trimmomatic.%j.out
#SBATCH -e trimmomatic.%j.err

#my directories
topdir=/home/rafaubc/scratch/rafaubc/Douglas-fir_GBS_GeneSolve
plate=${topdir}/Plate1_E02749/150bp_B/150bp
fastqs=${plate}/GbprocesS_output
adapter=${plate}/illumina_adapters

cd ${fastqs}
outdir=${plate}/trim_retry_2_demux_py
if [[ ! -d ${outdir} ]] ; then
mkdir ${outdir}
fi

module load StdEnv/2023 trimmomatic/0.39

ls -1 *_R1.fastq > files.tmp
for R1 in $(cat files.tmp) ; do
  R2=$(echo "$R1" | sed 's/_R1/_R2/g')
  base=${R1/_R1.fastq/}

  java -Xmx2G -jar $EBROOTTRIMMOMATIC/trimmomatic-0.39.jar PE \
  -threads 24 -phred33 -trimlog ${outdir}/${base}_log \
  ${R1} ${R2} \
  ${outdir}/${base}_trim_R1_paired.fastq.gz \
  ${outdir}/${base}_trim_R1_unpaired.fastq.gz \
  ${outdir}/${base}_trim_R2_paired.fastq.gz \
  ${outdir}/${base}_trim_R2_unpaired.fastq.gz \
  ILLUMINACLIP:${adapter}/TruSeq3-PE-2.fa:2:30:10 \
  LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:30
done && rm files.tmp

#end
