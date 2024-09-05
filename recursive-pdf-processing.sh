#!/bin/bash
###########################
# Written by Jacques Boucher
# jboucher@unicef.org
scriptVersion="5 September 2024"
# Tested on Kali Linux 2023.1 and Kali Linux on WSL.
##############################
# Installing required binaries
##############################
# If running on Kali Linux WSL, you will need to run the following:
# sudo apt update
# sudo apt upgrade
# sudo apt install exiftool
# sudo apt install xpdf
# sudo apt install pdf-parser
# sudo apt install poppler-utils
# sudo apt install pdfid

#################
# Troubleshooting
#################
# If the script gives you a warning that one of the above binaries is missing,
# you can search which package you need to install as follows:
# sudo apt search pdfinfo
# The above would search the packages and return that it's part of poppler-utils. You would then install that
# package with the command: sudo apt install poppler-utils.
#
# As best as the author could test, the installation of the required binaries above should be all that's needed.

####################
# Processing summary
####################
# This script will run the following parsing tools against a PDF that you provide as a command line argument.
# The script will check if a command is present. If it is not, it will note same in the log, alert you on screen, and skip that processing.
#
# 1 - pdfinfo
# 2 - exiftool
# 3 - pdfimages
# 4 - pdfsig
# 5 - pdfid
# 6 - pdf-parser
# 7 - pdffonts
# 8 - pdfdetach
#
#  The script will also extracts versions of the pdf using grep and dd commands, looking for the %%EOF string in the PDF.
#  Each time you edit a PDF within Adobe, it adds 
#
######################
# Command line options
######################
# -f <filename.pdf>		PDF being processed (required option)
# -v					Prints the version # of the script and exits.
# -p TRUE/FALSE			optional switch if you want to process prior versions of a PDF if present. If you don't include this option on the command line and prior versions are detected, 
#						the script will prompt you, letting you know it found prior versions and ask if you want to process them.
#						This option is especially practical if you extracted prior versions of a PDF, and now want to run the script against one of those PDFs.
#						In that scenario, you likely don't need to extract prior versions yet again. So you can use the option -p FALSE.
#
# Exit Codes
commandsExecuted=0 # if no commands are missing, will have an exit code of 0. If any command are missing, it will add 10**(command #) to the exit code.
		# example, if pdfinfo is missing, it will add 10**1, or 10 to the exit value.
		# if pdfsig is missing, it will add 10**4, or 10000 to the exit value.
		# this sort of mimics bit-wise values in that an exit value of 1010 means commands #1 and #3 did not run.
		# thus an exit value of 0 means all commands were executed.
missingArg=1 # missing an argument after the switch
tooManyArgs=2 # too many arguments
invalidSwitch=3 # invalid switch
missingSwitch=4 # switch not provided
invalidSyntax=5 # invalid syntax
fileDoesNotExist=6 # file does not exist
emptyFile=7 # 0 byte file provided as argument
badpdf=8 # if a bad PDF is passed to the script and the user chooses to exit without processing it.
f_and_d=9 # provided both -f and -d options
noFolder=10 # did not provide a folder parameter with the -d option

# Other variables
investigator=""
caseNumber=""
currentDateTime=$(date +%d-%m-%YT%H%M%S)
directory=0 # set default to false, not parsing a directory
executionFolder=$(pwd)
filename="" # initialize filename to process to blank
filenamenoext="" # filename without the extension
folder="" # folder to parse
extension="" # extension for the filename
newfile="" # varible to hold new filename when parsing through PDF for versions.
allimages="" # varible for file name where all image hashes are saved for each comparison.
v=1 # counter for versions of a PDF (applicable when a PDF has been edited with Adobe).
offsets=() # array variable to hold offsets of the %%EOF markers in a pdf denoting the end of each version.
versions=0 # variable to hold # of versions found in a PDF (i.e., number of %%EOF markers).
switch="" # initialize command line switch to blank
recursive=0 # set default to false, not recursive - ignored if -d not used.
outputFolder=""
RED='\033[0;31m' # red font
YELLOW='\033[0;1;33m' # yellow font
GREEN='\033[32;1;1m' # green font
NOCOLOUR='\033[0;m' # no colour
usage="Usage: $0 {-f <filename>} {-p} {-d <directory>} {-r}\nor: $0 -v"
priorVersion="" #This variable is the flag for deciding if the script should attempt to extract prior versions.
OIFS="$IFS" # Original Field Separator
IFS=$'\n' # New field separator = new line


hashMark() { # function to write section header to the log file.
	echo -e "######################### $1 #############################" >>"$logfile"
}

fileheader() { # function to write the file header to the log file.
	echo -e "*************************************************************************************************" >>"$logfile"
	echo -e "	Processing $1" >>"$logfile"
	echo -e "*************************************************************************************************" >>"$logfile"
	blankLine
}

blankLine() { # inserts a blank line in the log file and on screen.
	echo ""
	echo -e "" >>"$logfile"
}

commandNotFound () { #command not found. Logging same.
	echo ""
	echo -e "################ ${RED}WARNING!${NOCOLOUR} ################"
	echo -e "${RED}$1 ${YELLOW}not found!${NOCOLOUR} Skipping this step."
	echo -e "##########################################"
	echo ""
	blankLine
	echo "######## WARNING! ########" >> "$logfile"
	echo "$1 not found. Skipping this step." >> "$logfile"
	echo "##########################" >> "$logfile"
	blankLine
}

pdfImages() {
	#pdfimages
	
	which pdfimages >/dev/null #checks for command
	if [ $? -eq 0 ] # exit status 0 = command found
	then
		hashMark "$2 - $(pdfimages -v 2>&1 | head -n1)"
		echo "Extracting images from $1."
		echo "Extracting images from $1." >>"$logfile"

		blankLine
		pdfimagesRoot="$3"
		echo "executing: pdfimages -all \"$1\" \"$pdfimagesRoot\"" | tee -a "$logfile"
		echo "Which will extract the following images:" | tee -a "$logfile"
		pdfimages -list "$1" | tee -a "$logfile"
		pdfimages -all "$1" "$pdfimagesRoot"
		echo -e "\npdfimages finished execution at $(date).\nExtracted images saved to '$pdfimagesRoot-###.{extension}'.">>"$logfile"
		echo "executing: sha256sum \"$pdfimagesRoot\-*.*\"" | tee -a "$logfile"
		sha256sum "$pdfimagesRoot"-*.* | tee -a "$allimages"-unsorted.txt >> "$logfile"
		blankLine
	else
		commandNotFound "pdfimages"
		commandsExecuted=$commandExecuted+1000
	fi
}

checkPDF() {
	processThisPDF="y" # defaults to yes
	testPDF="$(pdfinfo "$1" 2>/dev/null)"
	if [ "$testPDF" == "" ]; then
		pdfValidation="False"
	else
		pdfValidation="True"
	fi
	
	if [ "$pdfValidation" == "False" ]; then
		echo -e "${YELLOW}Warning!${NOCOLOUR}\nThe PDF $1 does not appear to be a valid PDF."
		echo -e "According to pdfinfo, ${1} does not appear to be a valid PDF." >> "$logfile"
		read -p "Do you still wish to proceed (y/n)? " processThisPDF
		processThisPDF=$(echo $processThisPDF | tr '[:upper:]' '[:lower:]')
	fi
	}

while getopts ":d:f:p:rv" opt; do
	case $opt in
		d)
			switch=$opt
			folder="$OPTARG"
			if [ -z "$folder" ]; then
				echo -e "You ${RED}did not${NOCOLOUR} provide a ${RED}folder${NOCOLOUR} with the -d switch."
			elif [ ! -d "$folder" ]; then
				echo -e "You ${RED}did not${NOCOLOUR} provide a valid ${RED}folder${NOCOLOUR} with the -d switch."
				IFS="$OIFS" # restore IFS to original
				exit $noFolder
			fi
			;;
		f)
			switch=$opt
			filename="$OPTARG"
			if [ ! -z "$filename" ] && [ ! -z "$folder" ]; then
				echo -e "You provided ${RED}both${NOCOLOUR} the file (-f) and directory (-d) switches."
				echo -e "Please provide ${GREEN}one or the other${NOCOLOUR}, but ${RED}not both.${NOCOLOUR}"
				IFS="$OIFS" # restore IFS to original
				exit $f_and_d
			elif [ -z "$filename" ]; then #filename is still blank, thus invalid syntax
				echo "Invalid syntax."	
				echo -e $usage
				IFS="$OIFS" # restore IFS to original
				exit $invalidSyntax
			elif [ ! -f "$filename" ]; then
				echo "File does not exist."
				echo -e $usage
				IFS="$OIFS" # restore IFS to original
				exit $fileDoesNotExist
			elif [ ! -s "$filename" ]; then
				echo "The file $filename is a 0 byte file."
				echo "Nothing to process."
				echo -e $usage
				IFS="$OIFS" # restore IFS to original
				exit $emptyFile
			fi
			;;
		v)
			echo "$0 version: $scriptVersion"
			IFS="$OIFS" # restore IFS to original
			exit
			;;
		p) # attempt to extract prior versions
			switch=$opt
			priorVersion="$OPTARG" 
			priorVersion=$(echo $priorVersion | tr '[:upper:]' '[:lower:]')
			;;
		r)
			recursive=1 # user selected option to recursively search for files.
			;;
		:)
			echo "You must supply an argument to -$OPTARG">&2
			echo -e $usage
			IFS="$OIFS" # restore IFS to original
			exit $missingArg
			;;

		\?)
			echo "Invalid switch."
			echo -e $usage
			IFS="$OIFS" # restore IFS to original
			exit $invalidSwitch
			;;
	esac
done

outputFolder="report_$currentDateTime"

if [ -z "$switch" ]; then #switch is still blank, thus not provided
	echo "Did not provide the required switch."	
	echo -e $usage
	IFS="$OIFS" # restore IFS to original
	exit $missingSwitch
fi

# if a folder is passed, assign output of "find" command to files.

if [ ! -z $folder ]; then
	if [ $recursive -eq 1 ]; then
		filename=$(find $folder -iname "*.pdf")
	else
		filename=$(find $folder -maxdepth 1 -iname "*.pdf")
	fi
fi

mkdir $outputFolder

logfile="$outputFolder/processing_results.log"

hashMark "Tombstone Info"
read -p "Investigator: " investigator
read -p "Case number: " caseNumber

echo "Executed by user $(whoami) at $(date)." >> "$logfile"
echo "Investigator: $investigator" >> "$logfile"
echo "Case number: $caseNumber" >> "$logfile"
echo "Current folder: $executionFolder" >> "$logfile"
echo "Script version: "$scriptVersion >> "$logfile"
echo "Command executed:$0 $@" >> "$logfile"
# echo output folder
blankLine

fileCount=0

for fileToProcess in $filename # loop through each file
	do
	fileCount=$((fileCount+1))
	filenamenoext="${fileToProcess%.*}"
	filenamenoext="${filenamenoext##*/}"
	extension="${fileToProcess##*.}"
	blankLine
	fileheader $fileToProcess
	blankLine
	echo "Creating output folder $outputFolder/$fileCount-$filenamenoext for this file." >> "$logfile"
	blankLine
	fileFolder="$outputFolder/$fileCount-$filenamenoext"
	mkdir $fileFolder
	echo "sha256 hash: $(sha256sum "$fileToProcess" | cut -d " " -f1)" >> "$logfile"
	blankLine
	
	checkPDF "$fileToProcess"

	if [ "$pdfValidation" == "False" ]; then
		if [ "$processThisPDF" != "y" ]; then
			echo "User opted to not process \"$fileToProcess\" as it does not appear to be a valid PDF according to pdfinfo." | tee -a "$logfile"
			blankLine
			continue # skip out of the loop
		else
			echo "User opted to process \"$fileToProcess\" despite appearing to not be a vlaid PDF according to pdfinfo." | tee -a "$logfile"
			blankLine
		fi
	fi
	
	imagesFileName=$(basename ${fileToProcess})
	allimages="$fileFolder/"${imagesFileName%.*}"-hashes of all images"

	# pdfinfo

	which pdfinfo >/dev/null #checks for command
	if [ $? -eq 0 ] # exit status 0 = command found
	then
		pdfInfoFile="$fileFolder/${fileToProcess##*/}-pdfinfo.txt"
		hashMark "1 - $(pdfinfo -v 2>&1 | head -n 1)"
		echo "executing pdfinfo \"$fileToProcess\"" | tee -a "$logfile"
		pdfinfo "$fileToProcess">"$pdfInfoFile"
		echo -e "pdfinfo finished execution at $(date).\nResults written to '$pdfInfoFile'." >> "$logfile"
		echo "executing: sha256sum \"$pdfInfoFile\"" | tee -a "$logfile"
		sha256sum "$pdfInfoFile" >> "$logfile"

		blankLine
	else
		commandNotFound "pdfinfo"
		commandsExecuted=$commandExecuted+10
	fi

	# exiftool

	which exiftool >/dev/null #checks for command
	if [ $? -eq 0 ] # exit status 0 = command found
	then
		exifFile="$fileFolder/${fileToProcess##*/}-exif.csv"
		hashMark "2 - exiftool version $(exiftool -ver)"
		echo "executing: exiftool -a -G1 -s -ee -csv \"$fileToProcess\" > \"$exifFile\"" | tee -a "$logfile"
		exiftool -a -G1 -s -ee -csv "$fileToProcess">"$exifFile"
		echo -e "exiftool finished execution at $(date).\nResults written to '$fileFolder/$exifFile'.">>"$logfile"
		echo "executing: sha256sum \"$exifFile\"" | tee -a "$logfile"
		sha256sum "$exifFile" >> "$logfile"
		blankLine
	else
		commandNotFound "exiftool"
		commandsExecuted=$commandExecuted+100
	fi

	#pdfimages
	pdfImages "$fileToProcess" "3" "$fileFolder/${fileToProcess##*/}-pdfimages"

	#pdfsig

	which pdfsig >/dev/null #checks for command
	if [ $? = 0 ] # exit status 0 = command found
	then
		hashMark "4 - $(pdfsig -v 2>&1 | head -n1)"
		pdfsigFilename="$fileFolder/$filenamenoext.pdfsig.txt"
		echo "executing: pdfsig -nocert -dump \"$fileToProcess\"" | tee -a "$logfile"
		pdfsig -nocert -dump "$fileToProcess" >>"$logfile"
		
		if [ -e "$executionFolder/${fileToProcess##*/}.sig0" ]; then # if it extracted a signature file.
			mv $executionFolder/${fileToProcess##*/}.sig* "$fileFolder" # move the file(s) to the correct folder
			echo "executing: sha256sum \"$fileFolder/${fileToProcess##*/}.sig*\"" | tee -a "$logfile"
			sha256sum $fileFolder/${fileToProcess##*/}.sig* | tee -a "$logfile"
		fi
		
		echo -e "pdfsig finished execution at $(date).\nResults written to '$pdfsigFilename'.">>"$logfile"
		echo -e "Signature(s), if present, is/are dumped to $fileFolder.">>"$logfile"
		blankLine
	else
		commandNotFound "pdfsig"
		commandsExecuted=$commandExecuted+10000
	fi

	#pdfid

	which pdfid >/dev/null #checks for command
	if [ $? -eq 0 ] # exit status 0 = command found
	then
		hashMark "5 - pdfid version $(pdfid --version | cut -d " " -f2)"
		pdfidFilename="$fileFolder/$filenamenoext.pdfid.txt"
		echo "executing: pdfid -l \"$fileToProcess\">\"$pdfidFilename\"" | tee -a "$logfile"
		pdfid -l "$fileToProcess">"$pdfidFilename"
		echo -e "pdfid finished execution at $(date).\nResults written to '$pdfidFilename'.">>"$logfile"
		echo "executing: sha256sum \"$pdfidFilename\"" | tee -a "$logfile"
		sha256sum "$pdfidFilename" >> "$logfile"
		blankLine
	else
		commandNotFound "pdfid"
		commandsExecuted=$commandExecuted+100000
	fi

	#pdfparser

	which pdf-parser >/dev/null #checks for command
	if [ $? -eq 0 ] # exit status 0 = command found
	then
		hashMark "6 - pdf-parser version $(pdf-parser --version | grep "pdf-parser" | cut -d " " -f2)"
		pdfparserFilename="$fileFolder/$filenamenoext.pdfparser.txt"
		echo "executing: pdf-parser \"$fileToProcess\">\"$pdfparserFilename\"" | tee -a "$logfile"
		pdf-parser "$fileToProcess">"$pdfparserFilename"
		echo -e "pdf-parser finished execution at $(date).\nResults written to '$pdfparserFilename'.">>"$logfile"
		echo "executing: sha256sum \"$pdfparserFilename\"" | tee -a "$logfile"
		sha256sum "$pdfparserFilename" >> "$logfile"
		blankLine
	else
		commandNotFound "pdf-parser"
		commandsExecuted=$commandExecuted+1000000
	fi

	#pdffonts

	which pdffonts >/dev/null #checks for command
	if [ $? -eq 0 ] # exit status 0 = command found
	then
		hashMark "7 - $(pdffonts -v 2>&1 | head -n1)"
		pdffontsFilename="$fileFolder/$filenamenoext.pdffonts.txt"
		echo "executing: pdffonts \"$fileToProcess\">\"$pdffontsFilename\" 2>>\"$pdffontsFilename\"" | tee -a "$logfile"
		pdffonts "$fileToProcess" >"$pdffontsFilename" 2>>"$pdffontsFilename" 
		echo -e "pdffonts finished execution at $(date).\nResults written to '$pdffontsFilename'.">>"$logfile"
		echo "executing: sha256sum \"$pdffontsFilename\"" | tee -a "$logfile"
		sha256sum "$pdffontsFilename" >> "$logfile"
		blankLine
	else
		commandNotFound "pdffonts"
		commandsExecuted=$commandExecuted+10000000
	fi

	#pdfdetach

	which pdfdetach >/dev/null #checks for command
	if [ $? -eq 0 ] # exit status 0 = command found
	then
		hashMark "8 - $(pdfdetach -v 2>&1 | head -n1)"
		echo "executing: pdfdetach -saveall \"$fileToProcess\"" | tee -a "$logfile"
		echo "Which will extract the following files (if applicable):" | tee -a "$logfile"
		embeddedItemsCount=$(pdfdetach -list "$fileToProcess"|wc -l)
		embeddedItemsCount=$((embeddedItemsCount-1))
		pdfdetach -list "$fileToProcess" | tee -a "$logfile"
		pdfdetach -saveall "$fileToProcess"
		echo -e "pdfdetach finished execution at $(date).">>"$logfile"

		if [[ "$(pdfdetach -list "$fileToProcess")" != "0 embedded files" && "$(pdfdetach -list "$fileToProcess")" != "" ]] 
		# if there are no embedded files and you do the sha256sum command, it waits for input. This avoids hanging the script in such cases.
			then
			pdfdetach -list "$fileToProcess"|tail -n $embeddedItemsCount | cut -d: -f2
			for f in "$((pdfdetach -list "$fileToProcess")|tail -n $embeddedItemsCount | cut -d: -f2 2>/dev/null)"; do
				echo "executing: sha256sum \"${f#\"${f%%[![:space:]]*}\"}\"" | tee -a "$logfile"
				sha256sum "${f#"${f%%[![:space:]]*}"}" |tee -a "$logfile"
			done
		fi
	else
		commandNotFound "pdfdetach"
		commandsExecuted=$commandExecuted+10000000
	fi

	blankLine

	#extract versions of the PDF using grep and dd, commands commonly available on any Linux distro

	hashMark "9 - Extracting prior versions of the PDF"

	v=1

	offsets=($(grep --only-matching --byte-offset --text "%%EOF" "$fileToProcess"| cut -d : -f 1))

	if [ ${offsets[0]} -lt 600 ]; then
		unset offsets[0] # removes the first element in the array, as it's a false positive.
	fi

	priorVersions=${#offsets[@]}
	priorVersions=$((priorVersions-1))

	if [ $priorVersions -lt 1 ]; then
		echo "There are no previous versions of the PDF embedded in this pdf." | tee -a "$logfile"
	else
		if ! [[ "$priorVersion" = "true"  ||  "$priorVersion" = "false" ]]; then # if the user did not provide a valid option for -p (or did not specify it)
			echo -e "There are ${GREEN}$priorVersions prior versions${NOCOLOUR} of this PDF based on the number of %%EOF signatures in it.\n"
			echo "The script can attempt to extract them with the caveat that a prior version may or may not be a properly formed PDF."
			read -p "Do you want the script to attempt to extract all versions of this PDF (Y/N)? [Y] " priorVersion # default response is Y if user just hits ENTER
		
			if [[ "$priorVersion" == "Y" || "$priorVersion" == "y" || "$priorVersion" == "" ]]; then
				priorVersion="true"
			else
				priorVersion="false"
			fi
		fi
		if [ "$priorVersion" == "true" ];then # process prior versions
			echo "Excluding the current version, there are $((priorVersions-1)) prior versions in this PDF." | tee -a "$logfile"
			echo "The script will extract each of them, assiging them a version number. Version 1 being the oldest version, and version $priorVersions being the version prior to the current version." | tee -a "$logfile"

			#unset offsets[0] # removes the first element in the array, as it's a false positive.

			for size in ${offsets[@]}; do
			
			
				if [ $v -le $priorVersions ]; then # if it's not the last version. Last version is redundant, as it's the original PDF passed to the script.

					newfile="$fileFolder/$filenamenoext version $v.$extension"

					blocksize=$((size+7))

					blankLine
					echo "executing: dd if=\"$fileFolder/$fileToProcess\" of=\"$fileFolder/$newfile\" bs=$blocksize count=1 status=noxfer 2\> \/dev\/null" | tee -a "$logfile"
					echo "This will extract version $v of the pdf $fileToProcess, assigning it the new filename $fileFolder/$newfile" | tee -a "$logfile"
					echo ""

					dd if="$fileToProcess" of="$newfile" bs=$blocksize count=1 status=noxfer 2> /dev/null

					echo "executing: sha256sum \"$newfile\" >>\"$logfile\"" | tee -a "$logfile"
					sha256sum "$newfile" >>"$logfile"

					blankLine
					
					checkPDF "$newfile"
					
					if [ "pdfValidation" == "False" ] && [ "processThisPDF" != "y" ]; then
						echo "User opted to not process \"$newfile\" as it does not appear to be a valid PDF." >> "$logfile"
						continue # skip out of the loop
					fi
					
					if [ "$pdfValidation" == "True" ] # Valid PDF
					then
						echo -e "Prior ${GREEN}version $v${NOCOLOUR} of '$fileFolder/$fileToProcess' appears to be a ${GREEN}valid PDF.${NOCOLOUR}"
						echo -e "Prior version $v of '$fileFolder/${fileToProcess##*/}' appears to be a valid PDF." >> "$logfile"
					else # Not a valid PDF
						echo -e "Prior ${YELLOW}version $v${NOCOLOUR} of '$fileFolder/$fileToProcess' ${RED}does not appear to be a valid PDF.${NOCOLOUR}"
						echo -e "Prior version $v of '$fileFolder/$fileToProcess' does not appear to be a valid PDF." >> "$logfile"
					fi
					blankLine			
					pdfImages "$newfile" "9.$v" "$fileFolder/${newfile##*/}-pdfimges" 2>/dev/null # Attempt to extract images from the version. Even if not a valid PDF, attempting regardless.
					
					v=$((v+1))
				fi
			done

			echo -e "\nExtracting prior versions of the PDF finished execution at $(date).">>"$logfile"

			echo "executing: exiftool -a -G1 -s -ee -csv \"$fileToProcess\" \"$fileFolder/$filenamenoext version *.$extension\" 2> /dev/null >> \"$fileFolder/${fileToProcess##*/} - all versions - exif.csv" | tee -a "$logfile"

			exiftool -a -G1 -s -ee -csv $fileToProcess $fileFolder/$filenamenoext*.$extension 2> /dev/null >> "$fileFolder/${fileToProcess##*/} - all versions - exif.csv"
	
		fi
	fi

	# sorting all image hashes after extracting all prior versions of PDF for ease of identifying matching images

	blankLine

	echo "executing: sort \"$allimages\" > \"$allimages\"-sorted.txt" | tee -a "$logfile"
	echo -e "All images hashes are also found in: ${GREEN}'$allimages-sorted.txt'.${NOCOLOUR}"
	echo "All images hashes are also found in: $allimages-sorted.txt.">>"$logfile"

	sort "$allimages-unsorted.txt" > "$allimages"-sorted.txt
	
	blankLine

done

echo -e "\n###############################################################"
echo -e "Log file written to: ${GREEN}'$logfile'.${NOCOLOUR}"
echo -e "Script finshed at $(date)." >> "$logfile"
IFS="$OIFS" # restore IFS to original
exit $commandsExecuted