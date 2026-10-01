#!/bin/bash
#SBATCH --job-name=gbs_demux
#SBATCH --account=def-saitken
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=%x-%j.out

# Load the environment
module load python/3.10

# Ensure cutadapt is available in your user space via CC wheels
pip install --user --no-index cutadapt

# Execute the python script
# Make sure the filename matches the script created above
python3 demux_python_script.py
