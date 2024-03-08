# Written by Jacques Boucher
# jjrboucher@gmail.com
#
# Triage script to review multiple PDFs in folders/subfolders and extract
# a few data points that can help identify possible PDFs warranting further
# review for possible manipulation by a subject.
#
# You can modify the script to extract other fields if they are of interest to you.
# Updated 24 January 2024

output_file="pdf-triage.tsv"

if test -f $output_file; then
	echo "$output_file already exists. Rename or move and re-run the script."
	exit
fi

OIFS="$IFS" # Original Field Separator
IFS=$'\n' # New field separator = new line

a=$(find . -iname "*.pdf") # Find all PDFs recursively from current folder
echo "file	Create Date	Modify Date	# of images	Author	# of fonts	# of versions	hash" >$output_file # write headers to csv
for i in $a # loop through each item
do
	image_count=$(pdfimages -list $i | wc -l) # get only # of lines in output (# of images)
	image_count=$((image_count-2)) # substract 2 lines - headers - to get actual # of images
	author=$(exiftool -S -s -author $i) # get author of the document without the tag name
	create_date=$(exiftool -S -s -CreateDate $i)
	modify_date=$(exiftool -S -s -ModifyDate $i)
	font_count=$(pdffonts $i | wc -l) # get the # of fonts - but includes 2 additional lines for header.
	font_count=$((font_count-2)) # remove the headers
	hash=$(md5sum $i | cut -d " " -f1)
	offsets=($(grep --only-matching --byte-offset --text "%%EOF" "$i"| cut -d : -f 1)) # find all %%EOF instances in the PDF
	version_count=${#offsets[@]} # Number of instances of %%EOF
	if [ ${offsets[0]} -lt 600 ]; then
		unset offsets[0] # removes the first element in the array, as it's a false positive.
	fi
	echo "$i	$create_date	$modify_date	$image_count	$author	$font_count	$version_count	$hash" >>$output_file # append results to csv file in current directory
done

echo "Results can be found in $output_file."
IFS="$OIFS" # restore IFS to original