#!/bin/bash
# ffmpeg autocompressing script
# made by Sgorblex

set -e


usage() {
echo -e \
"$0: ffmpeg autocompress script by Sgorblex.

USAGE:
\t$0 [OPTION]

OPTIONS:
\t-s, --shutdown\t\tShutdown computer after finishing
\t-h, --hibernate\t\tHibernate computer after finishing
\t--help\t\t\tShow this help"
}

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
			if [[ -n $hibernate ]]
			then
				echo "Pick one: shutdown vs hibernate"
				exit 1
			fi
			;;
		-h|--hibernate)
			hibernate="true"
			if [[ -n $shutdown ]]
			then
				echo "Pick one: shutdown vs hibernate"
				exit 1
			fi
			;;
		--docrop)
			docrop="true"
			;;
		--help)
			usage
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

	echo -e "Done:\t$(ls "$elaborateddir" | wc -l)"
	echo -e "Remaining:\t$(ls "$tododir" | wc -l)"
	echo -e "Old name:\t$oldname\nNew name:\t$newname"
	echo -e "Start:\t$(date +%F_%T)" >> compressing.log
	echo -e "Old name:\t$oldname\nNew name:\t$newname" >> compressing.log

	echo -n "Compressing video... " >> compressing.log

	if [ -n $docrop ]; then
		crop=$(ffmpeg -ss 10 -i "$tododir/$oldname" -t 1 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1)
		# ffmpeg -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 -vf "$crop" "$elaborateddir/$newname"
		ffmpeg-bar -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 -vf "$crop" "$elaborateddir/$newname"
	else
		# ffmpeg -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 "$elaborateddir/$newname"
		ffmpeg-bar -y -i "$tododir/$oldname" -preset superfast -c:v libx265 -crf 31 -c:a aac -b:a 64k -ac 1 -r 24 "$elaborateddir/$newname"
	fi

	echo "Done."
	echo "Done." >> compressing.log

	oldsize=$(sizeof "$tododir/$oldname")
	newsize=$(sizeof "$elaborateddir/$newname")
	echo -e "Original file size:\t$oldsize B\nNew file size:\t\t$newsize B" >> compressing.log

	if [ $oldsize -le $newsize ]
	then
		echo "Compressing was pointless... renaming and moving original with [N], deleting compressed"
		echo "--> [N] - removing compressed" >> compressing.log
		ln "$tododir/$oldname" "$originaldir/$oldname"
		mv "$tododir/$oldname" "$elaborateddir/${oldname%.*}_[N].${oldname##*.}"
		rm "$elaborateddir/$newname"
	else
		# echo "Compressing was useful! Renaming the new produced video with [C], deleting original"
		echo "Compressing was useful! Renaming the new produced video with [C], moving original"
		echo "--> [C] - removing original" >> compressing.log
		mv "$elaborateddir/$newname" "$elaborateddir/${newname%.mp4}_[C].mp4"
		# rm "$tododir/$oldname"
		mv "$tododir/$oldname" "$originaldir"/
	fi

	echo -e "Work done for $newname\n"
	echo -e "End:\t$(date +%F_%T)\n" >> compressing.log
done

echo "Task complete!"



if [[ -n $hibernate ]]
then
		echo "Hibernating in 10 seconds..."
		sleep 10
		systemctl hibernate
elif [[ -n $shutdown ]]
then
		echo "Shutting down in 10 seconds..."
		sleep 10
		shutdown -P now
fi
