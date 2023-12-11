# Written by Jacques Boucher
# jjrboucher@gmail.com
#
# Triage script to review multiple PDFs in folders/subfolders and extract
# a few data points that can help identify possible PDFs warranting further
# review for possible manipulation by a subject.
#
# You can modify the script to extract other fields if they are of interest to you.

if test -f pdf-triage.csv; then
	echo "pdf-triage.csv already exists. Rename or move and re-run the script."
	exit
fi

OIFS="$IFS" # Original Field Separator
IFS=$'\n' # New field separator = new line

a=$(find . -iname *.pdf) # Find all PDFs recursively from current folder
echo "file", "# of images", "Author", "# of versions" >pdf-triage.csv # write headers to csv
for i in $a # loop through each item
do
	image_count=$(pdfimages -list $i | wc -l) # get only # of lines in output (# of images)
	image_count=$((image_count-2)) # substract 2 lines - headers - to get actual # of images
	author=$(exiftool -S -s -author $i) # get author of the document without the tag name
	offsets=($(grep --only-matching --byte-offset --text "%%EOF" "$i"| cut -d : -f 1)) # find all %%EOF instances in the PDF
	version_count=${#offsets[@]} # Number of instances of %%EOF
	echo $i, $image_count, $author, $version_count >>pdf-triage.csv # append results to csv file in current directory
done

IFS="$OIFS" # restore IFS to original