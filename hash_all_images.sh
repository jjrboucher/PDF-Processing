OIFS="$IFS" # Original Field Separator
IFS=$'\n' # New field separator = new line
ORIGINAL_GLOB=$(shopt -p nocaseglob)
shopt -s nocaseglob # to make the ls command case insensitive

hashfile="hashes($(date -u +%a_%d-%b-%y_%kh%Mm%Ss)).csv"  # create the hash file using the UTC date to make it unique

for pdf in $(ls *.pdf); do # for all; PDFs in this folder
	echo "extracting images from $pdf"
	images=$(pdfimages "$pdf" "$pdf-image" -all -print-filenames)
	for image in $images; do  # for all images within the current PDF in the parent FOR loop
		echo "hashing $image"  # hash the file
		md5sum "$image" >>$hashfile  # output the hash file
		echo "Deleting $image"  # clean up after itself
		rm -f $image # deleting the image
		param_file="${image%.*}"
		param_file="${param_file##*/}"
		rm -f "$param_file.params"  # deleting the associated .params file.
	done
done

# reset values
IFS=$OIFS
$ORIGINAL_GLOB
