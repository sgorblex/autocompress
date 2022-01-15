#!/bin/sh
# autocompress.sh
# ffmpeg autocompressing script by Sgorblex

set -e


USAGE="$0: ffmpeg autocompress script by Sgorblex.

USAGE:
\t$0 [OPTION]

OPTIONS:
\t-s, --shutdown\t\tShutdown computer after finishing
\t-h, --hibernate\t\tHibernate computer after finishing
\t--docrop\t\tTry to crop black borders (based on the first seconds)
\t--help\t\t\tShow this help"


sizeof() {
	stat --printf="%s" "$1"
}


tododir=todo
elaborateddir=elaborated
originaldir=original


OPTS=sh
LONGOPTS=shutdown,hibernate,help,docrop

PARSED=$(getopt --options=$OPTS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$PARSED"

shutdown="" hibernate=""
while true
do
	case "$1" in
		-s|--shutdown)
			shutdown="true"
			if [ -n $hibernate ]
			then
				printf "Pick one: shutdown vs hibernate\n"
				exit 1
			fi
			;;
		-h|--hibernate)
			hibernate="true"
			if [ -n $shutdown ]
			then
				printf "Pick one: shutdown vs hibernate\n"
				exit 1
			fi
			;;
		--docrop)
			docrop="true"
			;;
		--help)
			printf "%s\n" "$USAGE"
			exit 0
			;;
		--)
			break
			;;
	esac
	shift
done


cd $(dirname $0)
mkdir -p "$tododir" "$elaborateddir" "$originaldir"

for oldname in "$tododir"/*
do
	oldname="${oldname##*/}"
	newname="${oldname%.*}.mp4"

	printf "Done:\t%s"	"$(ls "$elaborateddir" | wc -l)"
	printf "Remaining:\t%s"	"$(ls "$tododir" | wc -l)"
	printf "Old name:\t%s"	"$oldname\nNew name:\t$newname"
	printf "Start:\t%s"	"$(date +%F_%T)" >> compressing.log
	printf "Old name:\t%s\nNew name:\t%s\n"	"$oldname" "$newname" >> compressing.log

	printf "Compressing video... " >> compressing.log

	if [ -n $docrop ]; then
		crop=$(ffmpeg -ss 10 -i "$tododir/$oldname" -t 1 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1)
		# ffmpeg -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 -vf "$crop" "$elaborateddir/$newname"
		ffmpeg-bar -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 -vf "$crop" "$elaborateddir/$newname"
	else
		# ffmpeg -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 "$elaborateddir/$newname"
		ffmpeg-bar -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 "$elaborateddir/$newname"
	fi

	printf "Done.\n"
	printf "Done.\n" >> compressing.log

	oldsize=$(sizeof "$tododir/$oldname")
	newsize=$(sizeof "$elaborateddir/$newname")
	printf "Original file size:\t%s B\nNew file size:\t\t%s B\n" "$oldsize" "$newsize" >> compressing.log

	if [ $oldsize -le $newsize ]
	then
		printf "Compressing was pointless... renaming and moving original with [N], deleting compressed\n"
		printf "--> [N] - removing compressed\n" >> compressing.log
		ln "$tododir/$oldname" "$originaldir/$oldname"
		mv "$tododir/$oldname" "$elaborateddir/${oldname%.*}_[N].${oldname##*.}"
		rm "$elaborateddir/$newname"
	else
		# printf "Compressing was useful! Renaming the new produced video with [C], deleting original\n"
		printf "Compressing was useful! Renaming the new produced video with [C], moving original\n"
		printf "--> [C] - removing original\n" >> compressing.log
		mv "$elaborateddir/$newname" "$elaborateddir/${newname%.mp4}_[C].mp4"
		# rm "$tododir/$oldname"
		mv "$tododir/$oldname" "$originaldir"/
	fi

	printf "Work done for $newname\n\n"
	printf "End:\t$(date +%F_%T)\n\n" >> compressing.log
done

printf "Task complete!\n"



if [ -n $hibernate ]
then
		printf "Hibernating in 10 seconds...\n"
		sleep 10
		systemctl hibernate
elif [ -n $shutdown ]
then
		printf "Shutting down in 10 seconds...\n"
		sleep 10
		shutdown -P now
fi
