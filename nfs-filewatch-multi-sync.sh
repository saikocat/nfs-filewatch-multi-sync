#!/usr/bin/env bash

VERSION=0.1.0
DORMANT_THRESHOLD=2
DELETE_SOURCE_FILE=1
IGNORE_HIDDEN_AND_PARTIAL=1
PARALLEL_JOBS=5
POLLING_INTERVAL=30

function print_help {
    echo "You need to supply all the arguments"
    echo "  --help|-h                Print this help message."
    echo "  --dormant-threshold      Time to consider file to be dormant / not modified for x minute ago. Default $DORMANT_THRESHOLD minutes"
    echo "  --delete-source-file     Delete source file after complete. Default is $DELETE_SOURCE_FILE"
    echo "  --parallel-jobs          Number of parallel jobs. Default is $PARALLEL_JOBS"
    echo "  --watch-folder-fromfile  Path to file contains folders to watch"
    echo "  --dest-folder-fromfile   Path to file of contains folders to output"
    echo "  --ignore-hidden-and-partial-file    Ignore (.) hidden files (rsync partial) and .part file (ftp partial). Default is $IGNORE_HIDDEN_AND_PARTIAL"
    echo "  --polling-interval       Interval between each poll. Default $POLLING_INTERVAL seconds"
}

if [ $# -eq 0 ]; then
    print_help
    exit 0
fi

while [[ $# -ge 1 ]]
do
    KEY="$1"
    shift

    case $KEY in
        -h|--help)
            print_help
            exit 0
            ;;
        --parallel-jobs)
            PARALLEL_JOBS=$1
            shift
            ;;
        --polling-interval)
            POLLING_INTERVAL=$1
            shift
            ;;
        --dormant-threshold)
            DORMANT_THRESHOLD=$1
            shift
            ;;
        --delete-source-file)
            DELETE_SOURCE_FILE=$1
            shift
            ;;
        --watch-folder-fromfile)
            WATCH_FOLDER_FROMFILE=$1
            [ -f "${WATCH_FOLDER_FROMFILE}" ] || { echo "Cannot find $1"; exit 1; }
            shift
            ;;
        --dest-folder-fromfile)
            DEST_FOLDER_FROMFILE=$1
            [ -f "${DEST_FOLDER_FROMFILE}" ] || { echo "Cannot find $1"; exit 1; }
            shift
            ;;
        --ignore-hidden-and-partial-file)
            IGNORE_HIDDEN_AND_PARTIAL=$1
            shift
            ;;
        *)
            # unknown option
            ;;
    esac
done


if [ $IGNORE_HIDDEN_AND_PARTIAL -eq 0 ] ; then
    FIND_IGNORE_PATTERN=''
else
    FIND_IGNORE_PATTERN="\( ! -regex '.*/\..*' -not -name '*.part' \)"
fi


WATCH_FOLDERS=$(cat $WATCH_FOLDER_FROMFILE | tr "\n" " ")
DEST_FOLDERS=$(cat $DEST_FOLDER_FROMFILE | tr "\n" " ")

while true; do
    echo "[INFO] - Polling for changes"

    FEED_FILES=$(echo $FIND_IGNORE_PATTERN | xargs find ${WATCH_FOLDERS[@]} -maxdepth 1 -type f -mmin +${DORMANT_THRESHOLD})

    for FILE in ${FEED_FILES[@]}
    do
        echo "[INFO] - $FILE is syncing..."
        SOURCE_FILE=`basename $FILE`
        SOURCE_DIR=`dirname $FILE`
        SOURCE_FOLDER=`basename $SOURCE_DIR`
        parallel --jobs $PARALLEL_JOBS --halt 2 rsync -a --include="${SOURCE_FILE}" --exclude="*" ${SOURCE_DIR}/ {}/.tmp/${SOURCE_FOLDER} ::: ${DEST_FOLDERS[@]}
        RSYNC_RESULT=$?
        if [ $RSYNC_RESULT -eq 0 ]; then
            parallel --jobs $PARALLEL_JOBS mkdir -p {}/${SOURCE_FOLDER}\; mv {}/.tmp/${SOURCE_FOLDER}/${SOURCE_FILE} {}/${SOURCE_FOLDER} ::: ${DEST_FOLDERS[@]}
            if [ $DELETE_SOURCE_FILE -eq 1 ]; then
                rm -f $FILE
            fi
        else
            echo "[ERROR] - Failed to rsync $FILE_CHANGE!"
        fi
        echo "[INFO] - $FILE synced"
    done

    sleep $POLLING_INTERVAL
done
