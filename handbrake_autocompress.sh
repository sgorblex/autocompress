#!/bin/bash
# HandBrake autocompressing script
# made by Sgorblex

set -o errexit -o pipefail


function usage {
echo -e \
"$0: HandBrakeCLI autocompress script by Sgorblex.

USAGE:
\t$0 [OPTION]

OPTIONS:
\t-s, --shutdown\t\tShutdown computer after finishing
\t-h, --hibernate\t\tHibernate computer after finishing
\t--help\t\t\tShow this help"
}


OPTS=sh
LONGOPTS=shutdown,hibernate,help

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
noncompressidir=todo
compressidir=elaborated
originaldir=original
mkdir -p $noncompressidir $compressidir $originaldir

for oldname in $(ls $noncompressidir)
do
	newname=${oldname%.*}.mp4

	echo -e "Done:\t$(ls $compressidir | wc -l)"
	echo -e "Remaining:\t$(ls $noncompressidir | wc -l)"
	echo -e "Old name:\t$oldname\nNew name:\t$newname"
	echo -e "Start:\t$(date +%F_%T)" >> compressing.log
	echo -e "Old name:\t$oldname\nNew name:\t$newname" >> compressing.log

	echo -n "Handbraking video... " >> compressing.log

	HandBrakeCLI --preset-import-file handbrake_presets.json -Z "Fast Optimal SAS" -i $noncompressidir/$oldname -o $compressidir/$newname 2>&-

	echo "Done."
	echo "Done." >> compressing.log

	oldsize=$(ls -l $noncompressidir/$oldname | cut -d ' ' -f 5)
	newsize=$(ls -l $compressidir/$newname | cut -d ' ' -f 5)
	echo -e "Original file size:\t$oldsize B\nNew file size:\t\t$newsize B" >> compressing.log

	if [ $oldsize -le $newsize ]
	then
		echo "Compressing was pointless... renaming and moving original with [N], deleting compressed"
		echo "--> [N] - removing compressed" >> compressing.log
		ln $noncompressidir/$oldname $originaldir/$oldname
		mv $noncompressidir/$oldname $compressidir/${newname%.mp4}_[N].mp4
		rm $compressidir/$newname
	else
		# echo "Compressing was useful! Renaming the new produced video with [C], deleting original"
		echo "Compressing was useful! Renaming the new produced video with [C], moving original"
		echo "--> [C] - removing original" >> compressing.log
		mv $compressidir/$newname $compressidir/${newname%.mp4}_[C].mp4
		# rm $noncompressidir/$oldname
		mv $noncompressidir/$oldname $originaldir/
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
