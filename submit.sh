#!/bin/bash

#SBATCH --job-name=whisper
#SBATCH --nodes=2
#SBATCH --tasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=05-00:00:00
#SBATCH --mem=8GB
#SBATCH --mail-type=ALL
#SBATCH --mail-user=rasan@nyu.edu
#SBATCH --output=slurm-%j.out

. /etc/profile

source $HOME/venv/whisper/bin/activate

export PATH=$HOME/bin:$PATH

module load ffmpeg/4.2.4

set -u
# set -x

APP_HOME=$HOME/work/hpc-whisper

INPUT_DIR="$SCRATCH/input"

TMPDIR="$SCRATCH/tmp"


# Get list of video files to run whisper
FILES=(`find $INPUT_DIR -regextype posix-extended \
	-iregex '.*\.(avi|m4a|mov|mp4|wav)' | sort`)

NUM_FILES=${#FILES[@]}

if [ $NUM_FILES -eq 0 ]; then
	echo "Couldn't find any video files."
else
	echo "[NUM FILES] $NUM_FILES"
fi

# Calculate max runtime for video by multiplying the
# duration of the video by this number
MAX_RUNTIME_RATIO=5

fmt_time()
{
	local T=$1
	local D=$((T / 60 / 60 / 24))
	local H=$((T / 60 / 60 % 24))
	local M=$((T / 60 % 60))
	local S=$((T % 60))
	(( $D > 0 )) && printf '%02d:' $D
	printf '%02d:%02d:%02d\n' $H $M $S
}

max_runtime()
{
	local video_file=$1
	# get duration of video in milliseconds
	local duration=$(mediainfo --Inform="Video;%Duration%" $video_file)
	# convert duration to seconds
	duration=$((duration / 1000))
	# convert duration to int
	duration=${duration%.*}
	# Calculate max runtime
	local max_time=$((duration * MAX_RUNTIME_RATIO))
	# print max_time in days:hour:minute:seconds format
# 	TZ=UTC printf '%(%H:%M:%S)T\n' $max_time
	fmt_time $max_time
}

for i in ${!FILES[@]}
do
	infile=${FILES[${i}]}
	digid=${infile##*/}
	max_time=$(max_runtime $infile)
	srun \
		--job-name=${digid:-whisper} \
		--nodes=1 \
		--ntasks=1 \
		--cpus-per-task=$SLURM_CPUS_PER_TASK \
		--exclusive \
		--time=$max_time \
		whisper \
		--threads $SLURM_CPUS_PER_TASK \
		$infile &
	pids[$i]=$!
	sleep 1
done



NUM_DONE=0
NUM_FAIL=0

while [ $NUM_DONE -lt $NUM_FILES ]
do
	for i in ${!FILES[@]}
	do
		if [ ${pids[${i}]} -gt 0 ] && ! kill -0 ${pids[${i}]} &> /dev/null; then
			echo "Waiting on pids[$i] ${pids[${i}]}: ${FILES[${i}]}"
			wait ${pids[${i}]}
			RETVAL=$?
			if [ $RETVAL -gt 0 ]; then
				let "NUM_FAIL+=1"
			fi
			let "NUM_DONE+=1"
			pids[$i]=-1
			orig_file=${FILES[${i}]}
			orig_file=${orig_file/#$INPUT_DIR/}
			echo "RETVAL[$i] $orig_file $RETVAL"
		fi
	done
	sleep 60
done

echo "[NUM FAIL]: $NUM_FAIL"

printf '[SBATCH_START_TIME] %(%s)T\n' -2
printf '[SBATCH_END_TIME] %(%s)T\n' -1

exit $NUM_FAIL

