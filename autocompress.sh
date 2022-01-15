#!/bin/sh
# autocompress.sh
# ffmpeg autocompressing script by Sgorblex

set -e

FFMPEG_PRESET=superfast
FFMPEG_VIDEO=libx265
FFMPEG_CRF=31
FFMPEG_AUDIO=aac
FFMPEG_AUDIO_BITRATE=64k
FFMPEG_AUDIO_CHANNELS=1

command -v ffmpeg-bar >/dev/null && FFMPEG_COMMAND=ffmpeg-bar || FFMPEG_COMMAND=ffmpeg

LOGFILE=~/.local/share/autocompress.log

INPUT_DIR=todo
OUTPUT_DIR=elaborated
BACKUP_DIR=original


USAGE="$0: ffmpeg autocompress script by Sgorblex.

USAGE:
$0 [OPTIONS]

OPTIONS:
-o, --output DIR		Output directory (default: $OUTPUT_DIR)
-i, --input DIR			Input directory (default: $INPUT_DIR)
-b, --backup DIR		Move the originals in this location (default: $BACKUP_DIR,
				overridden by -d)
-c, --crop			Try to crop black borders (based on the first seconds)
-t, --mtime			Adjust mtime output to match original
-r RATE, --rate RATE		Lower the framerate to RATE if convenient
-d, --delete			Delete original after
-a ACTION, --after ACTION	Execute ACTION upon completing operation (see below)
-h, --help			Show this help

ACTION is one of
h, hibernate			Hibernate computer (systemd)
s, shutdown			Shutdown computer (shutdown)
n, notify			Send notification (notify-send)"


sizeof() {
	stat --printf="%s" "$1"
}


OPTS=o:i:b:ctr:da:h
LONGOPTS=output:,input:,backup:,crop,mtime,rate:,delete,after,help
PARSED=$(getopt --options=$OPTS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$PARSED"

while true
do
	case "$1" in
		-o|--output)
			OUTPUT_DIR="$2"
			shift
			;;
		-i|--input)
			INPUT_DIR="$2"
			shift
			;;
		-b|--backup)
			BACKUP_DIR="$2"
			shift
			;;
		-c|--crop)
			CROP=true
			;;
		-t|--mtime)
			MTIME=true
			;;
		-r|--rate)
			RATE="$2"
			;;
		-d|--delete)
			DELETE=true
			;;
		-a|--after)
			OPT_AFTER="$2"
			shift
			;;
		-h|--help)
			printf "%s\n" "$USAGE"
			exit 0
			;;
		--)
			break
			;;
	esac
	shift
done

[ -d "$OUTPUT_DIR" ]	|| (printf "Invalid output directory: %s.\n"	"$OUTPUT_DIR";	 exit 1)
[ -d "$INPUT_DIR" ]	|| (printf "Invalid input directory: %s.\n"	"$INPUT_DIR";	 exit 1)
[ -d "$BACKUP_DIR" ]	|| (printf "Invalid backup directory: %s.\n"	"$BACKUP_DIR";	 exit 1)

if [ "$RATE" -le 0 ] 2>/dev/null; then
	printf "Invalid framerate: %s.\n" "$RATE"
	exit 1
fi

if [ -n "$OPT_AFTER" ]; then
	case "$OPT_AFTER" in
		h|hibernate)
			AFTER='printf "Hibernating in 10 seconds...\n"; sleep 10; systemctl hibernate'
			;;
		s|shutdown)
			AFTER='printf "Shutting down in 10 seconds...\n"; sleep 10; shutdown -P now'
			;;
		n|notify)
			AFTER="notify-send 'autocompress has finished its work. Enjoy!'"
			;;
		*)
			printf "Invalid ACTION for --after. See $0 --help.\n"
			exit 1
	esac
fi



[ -n "$FFMPEG_PRESET" ] && FFMPEG_OPTIONS="$FFMPEG_OPTIONS -preset $FFMPEG_PRESET"
[ -n "$FFMPEG_VIDEO" ] && FFMPEG_OPTIONS="$FFMPEG_OPTIONS -c:v $FFMPEG_VIDEO"
[ -n "$FFMPEG_CRF" ] && FFMPEG_OPTIONS="$FFMPEG_OPTIONS -crf $FFMPEG_CRF"
[ -n "$FFMPEG_AUDIO" ] && FFMPEG_OPTIONS="$FFMPEG_OPTIONS -c:a $FFMPEG_AUDIO"
[ -n "$FFMPEG_AUDIO_BITRATE" ] && FFMPEG_OPTIONS="$FFMPEG_OPTIONS -b:a $FFMPEG_AUDIO_BITRATE"
[ -n "$FFMPEG_AUDIO_CHANNELS" ] && FFMPEG_OPTIONS="$FFMPEG_OPTIONS -ac $FFMPEG_AUDIO_CHANNELS"



for oldname in $(ls $INPUT_DIR)
do
	newname="${oldname%.*}.mp4"

	printf "Done:\t%s\n"		"$(ls "$OUTPUT_DIR" | wc -l)"
	printf "Remaining:\t%s\n"		"$(ls "$INPUT_DIR" | wc -l)"
	printf "Start:\t%s\n"		"$(date +%F_%T)"		>> $LOGFILE
	printf "Current file:\t%s\n"	"$oldname"			>> $LOGFILE
	printf "Compressing video... "					>> $LOGFILE

	if [ -n "$RATE" ]; then
		currfps=$(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate "$INPUT_DIR/$oldname")
		currfps=$(( ${currfps%/*}/${currfps#*/} ))
		if [ "$RATE" -lt $currfps ]; then
			FFMPEG_OPTIONS="$FFMPEG_OPTIONS -r $RATE"
		fi
	fi
	if [ -n "$CROP" ]; then
		if cropsettings=$(ffmpeg -ss 10 -i "$INPUT_DIR/$oldname" -t 1 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1); then
			FFMPEG_OPTIONS="$FFMPEG_OPTIONS -vf $cropsettings"
		else
			printf "Couldn't detect cropping information. Proceeding without cropping.\n"
			printf "Couldn't detect cropping information. Proceeding without cropping.\n" >> $LOGFILE
		fi
	fi

	eval "$FFMPEG_COMMAND -y -i \"$INPUT_DIR/$oldname\" $FFMPEG_OPTIONS \"$OUTPUT_DIR/$newname\""

	printf "Done.\n"
	printf "Done.\n" >> $LOGFILE

	oldsize=$(sizeof "$INPUT_DIR/$oldname")
	newsize=$(sizeof "$OUTPUT_DIR/$newname")
	printf "Original file size:\t%s B\nNew file size:\t\t%s B\n" "$oldsize" "$newsize"	>> $LOGFILE

	if [ $oldsize -le $newsize ]
	then
		printf "Compressing was pointless... renaming and moving original with [N], deleting compressed\n"
		printf "%s\n" "--> [N] - removing compressed"	>> $LOGFILE
		mv "$INPUT_DIR/$oldname" "$OUTPUT_DIR/${oldname%.*}_[N].${oldname##*.}"
		rm "$OUTPUT_DIR/$newname"
	else
		if [ -n "$MTIME" ]; then
			touch -cr "$INPUT_DIR/$oldname" "$OUTPUT_DIR/$newname"
		fi
		if [ -n "$DELETE" ]; then
			printf "Compressing was useful! Renaming the new produced video with [C], deleting original\n"
			printf "%s\n" "--> [C] - deleting original"		>> $LOGFILE
			rm "$INPUT_DIR/$oldname"
		else
			printf "Compressing was useful! Renaming the new produced video with [C], moving original\n"
			printf "%s\n" "--> [C] - moving original"		>> $LOGFILE
			mv "$INPUT_DIR/$oldname" "$BACKUP_DIR/"
		fi
		mv "$OUTPUT_DIR/$newname" "$OUTPUT_DIR/${newname%.mp4}_[C].mp4"
	fi

	printf "Work done for $newname\n\n"
	printf "End:\t$(date +%F_%T)\n\n" >> $LOGFILE
done

printf "Task complete!\n"

if [ -n "$AFTER" ]; then
	eval "$AFTER"
fi
