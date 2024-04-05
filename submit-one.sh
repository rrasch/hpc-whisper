#!/bin/bash

#SBATCH --job-name=whisper
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=05-00:00:00
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

sbatch_dir="$(dirname "$(realpath "$0")")"
input_dir="$(dirname "$(realpath "$input_file")")"
name=$(basename -- "$input_file")
name="${name%.*}"
ext="${input_file##*.}"

source /etc/profile
source $APPHOME/funcs.sh
source $HOME/venv/whisper/bin/activate

export PATH=$HOME/bin:$PATH

module purge
# module load ffmpeg/$FFMPEG_VERSION
module load cuda/$CUDA_VERSION

set -u
set -x

TMPDIR="$SCRATCH/tmp"

max_time=$(max_runtime "$input_file")

srun \
	--job-name="$name" \
	--nodes=1 \
	--ntasks=1 \
	--cpus-per-task=$SLURM_CPUS_PER_TASK \
	--exclusive \
	--time=$max_time \
	whisper \
	--threads $SLURM_CPUS_PER_TASK \
	--language English \
	--model small \
	--model_dir $TMPDIR \
	--output_dir $input_dir \
	"$input_file" &

pid=$!

echo "Waiting on pid $pid: '$input_file'"
wait $pid
RETVAL=$?

echo "[EXIT_STATUS]: $RETVAL"
printf '[SBATCH_START_TIME] %(%Y-%m-%d %H:%M:%S)T\n' -2
printf '[SBATCH_END_TIME]   %(%Y-%m-%d %H:%M:%S)T\n' -1

exit $RETVAL
