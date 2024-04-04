# funcs.sh

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
