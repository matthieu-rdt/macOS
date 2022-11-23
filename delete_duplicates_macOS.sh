#/bin/bash

# This script deletes all duplicated files found in the input folder.
# If results are found, we ask the user to select the file to delete.
# It doesn't work recursively.
#
# Usage:
# bash delete-duplicates.sh [folder]
# 
# Tested on:
# - OS X El Capitan (10.11)
# - OS X Sierra (10.12)
# - OS X High Sierra (10.13)

if [ -z "$1" ]; then
    echo "No argument supplied. Running the script for the current directory"
else
    echo "Changing to dir $1"
    cd "$1"
fi

IFS=$'\n'

echo 'Looking for repeated files...'

# We store results, as we need to reuse them later
md5_files=$(md5 * 2>/dev/null)

# We create an array of unique duplicated hashes
repeated=$(echo "$md5_files" | sed 's/^MD5 (\(.*\)) = /\1\//g' | cut -d "/" -f 2 | sort | uniq -d)
if [ -z "$repeated" ]; then
    echo "No duplicates found"
    exit 0
fi

# We create an array of files which have at least one duplicate. It looks like:
# MD5 (<FILENAME>) = <HASH>
results=$(echo "$md5_files" | grep -f <(echo "$repeated") | sort -t "=" -k 2)

# Add a fake element result to the string, so the loop doesn't end incompleted
results+=$'\nMD5 (-) = -'

no_results=true
common=()
for result in $results
do
    # We extract for each result the filename and hash
    filename=`echo $result | sed 's/^MD5 (\(.*\)) = /\1\//g' | cut -d "/" -f 1`
    hash=`echo $result | sed 's/.* = \(.*\)/\1/g'`

    if ! [ -z "$hash_last" ] && [ "$hash" != "$hash_last" ]; then
        no_results=false
        for (( i=0; i<${#common[@]}; i++ ));
        do
            echo $i. ${common[$i]}
        done

        # If we have some case like:
        #   filename.jpg, filename (0).jpg, filename (1).jpg, filename (2).jpg
        # Or:
        #   filename.jpg, filename copy 1.jpg, filename copy 2.jpg
        # Then don't ask the user and delete the copies automatically.
        basename=$(basename "${common[${#common[@]}-1]%.*}")
        matches_basename=true
        for (( i=0; i<${#common[@]}-1; i++ ));
        do
            basename_cmp=$(basename "${common[$i]%.*}")
            if ! echo "$basename_cmp" | grep -q "$basename"; then
                matches_basename=false
                break
            fi
        done
        # Apply automatic deletion
        if $matches_basename; then
            for (( i=0; i<${#common[@]}-1; i++ ));
            do
                rm ${common[$i]}
                echo "- Deleted: ${common[$i]}"
            done
            echo
        # Ask the user for deletion
        else
            while true; do
                echo "Type the file number NOT to delete: "
                read num

                re='^[0-9]+$'
                if ! [[ $num =~ $re ]] ; then
                    echo "Please, answer with a number"
                else
                    if [[ $num == ${#common[@]} || $num > ${#common[@]} ]]; then
                        echo "Please, answer with a valid number"
                        continue
                    fi
                    for (( i=0; i<${#common[@]}; i++ ));
                    do
                        if [[ $i != $num ]]; then
                            rm ${common[$i]}
                            echo "- Deleted: ${common[$i]}"
                        fi
                    done
                    echo
                    break
                fi
            done
        fi

        common=()
        echo $common
    fi

    common+=($filename)
    hash_last=$hash
done

if $no_results; then
    echo "No duplicates found"
fi
