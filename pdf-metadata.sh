# Written by Jacques Boucher
# jjrboucher@gmail.com
#
# Triage script to review multiple PDFs in folders/subfolders and extract
# the metadata from each and output to a CSV file.

output_file="pdf-metadata.csv" # name of the file where results are saved.

if test -f $output_file; then
	echo "pdf-triage.csv already exists. Rename or move and re-run the script."
	exit
fi

exiftool -a -G1 -s -ee -csv -r . -ext pdf >>$output_file # append results to csv file in current directory

echo "Results in $output_file."