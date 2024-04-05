#!/bin/bash

#SBATCH --job-name=whisper
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:30:00
#SBATCH --mem=8GB
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rasan@nyu.edu
#SBATCH --output=slurm-%j.out

APPHOME=$HOME/work/hpc-whisper
CUDA_VERSION=11.6.2
FFMPEG_VERSION=4.2.4

if [ $# -ne 1 ]; then
	echo -e "\nUsage: $0 <audio_file>\n"
	exit 1
fi

input_file=$1

slurm_dir="$(dirname "$(realpath "$0")")"
input_dir="$(dirname "$(realpath "$input_file")")"
name=$(basename -- "$input_file")
name="${name%.*}"
ext="${input_file##*.}"

source /etc/profile
source $APPHOME/funcs.sh
source $HOME/venv/whisper/bin/activate

export PATH=$HOME/bin:$PATH

module purge
module load cuda/$CUDA_VERSION

set -u
set -x

export TMPDIR="$SCRATCH/tmp"

srun \
	--job-name="$name" \
	--nodes=1 \
	--ntasks=1 \
	--cpus-per-task=$SLURM_CPUS_PER_TASK \
	--exclusive \
	whisper \
	--threads $SLURM_CPUS_PER_TASK \
	--language English \
	--model small \
	--model_dir $TMPDIR \
	--output_dir $input_dir \
	"$input_file"

RETVAL=$?

echo "[EXIT_STATUS]: $RETVAL"
printf '[SBATCH_START_TIME] %(%Y-%m-%d %H:%M:%S)T\n' -2
printf '[SBATCH_END_TIME]   %(%Y-%m-%d %H:%M:%S)T\n' -1

exit $RETVAL
