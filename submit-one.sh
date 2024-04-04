#!/bin/bash

#SBATCH --job-name=whisper
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=05-00:00:00
#SBATCH --mem=8GB
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rasan@nyu.edu
#SBATCH --output=slurm-%j.out

if [ $# -ne 1 ]; then
	echo -e "\nUsage: $0 <audio_file>\n"
	exit 1
fi

input_file=$1

script_dir="$(dirname "$(realpath "$0")")"
input_dir="$(dirname "$(realpath "$input_file")")"
name=$(basename -- "$input_file")
name="${name%.*}"
ext="${input_file##*.}"

source /etc/profile

set -e

source $script_dir/funcs.sh
source $HOME/venv/whisper/bin/activate

export PATH=$HOME/bin:$PATH

module load ffmpeg/4.2.4

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
	--output_dir $input_dir \
	$input_file &

pid=$!

echo "Waiting on pid $pid: $input_file"
wait $pid
RETVAL=$?

echo "[EXIT_STATUS]: $RETVAL"
printf '[SBATCH_START_TIME] %(%s)T\n' -2
printf '[SBATCH_END_TIME]   %(%s)T\n' -1

exit $RETVAL
