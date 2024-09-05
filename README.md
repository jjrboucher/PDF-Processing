# recursive-pdf-processing.sh
Script to process a single PDF file, all PDF files in a folder, or all PDF files in a folder, recursively.

Script is still being worked on. I need to add an output option. Currently, it will output to a new directory ("report_DD-MM-YYYYTHH:mm:ss") based on where the script is run. This can result in unintended loop if the output folder resides within the recursive folder you have chosen to process. To avoid this, you can navigate to a location where you want an output folder to be created (will be unique as it uses the timestamp as part of the name), and using the -d to select the directory, select a directory located elsewhere. The ultimate purpose of this script would be to be able to mount an image file with the image mounter of your choice, and point the script to somewhere within that hierarchy (e.g., a user folder) to parse all PDFs within it.

This script was created out of the necessity to extract prior versions out of multiple PDFs. Rather than running the other script multiple times, pointing to a new file each time, this script will allow me to process those multiple PDFs in a single command.

If you are going to use this script, keep in mind that it is still being tested, and I will be adding an output command line parameter in the coming days hopefully. And I'll update this at that time with examples of syntax you can use.

For now, an example would be to navivate to your Documents folder on your C drive with Kali WSL for example (cd /mnt/c/Users/{username}/Documents), and run the following (assuming your script is in your user home folder and executable):

~/recursive-pdf-processing.sh -d /mnt/n/my_pdfs_are_here -r -p True

The above uses the following switches:
-d to specify the root directory to start processing. /mnt/n/my_pdfs_are_here
-r means to recursively parse
-p True tells the script to parse prior versions if any found. If you don't specify -p, it will prompt you when it finds a prior version. This wasn't a big deal when processing a single PDF, as you would be at the keyboard while it was processing. But if recursively processing 1000 PDFs for example, you don't want to have to answer whether or not to process prior versions each time it encounters one. So you can specify -p True (automatically process prior versions), or -p False (don't process prior versions). Anything else will result in being prompted for each.

You can still use the -f option as with the other script to parse a single PDF. Once this script is properly tested, the other will be retired.

Currently, you don't specify an output folder. It creates one under the folder from which the script is run. But I will be adding -o {output_folder} soon. That way you could, if you prefered, navigate to where you want to start processing PDFs and do the following:
~/recursive-pdf-processing -d . -r -p True -o /mnt/c/Users/{username}/Desktop
The above will (once I add the -o option) process all pdfs from your current folder (because you navigated to where you want to start), as denoted by the period ".". It will parse recursively, and parse prior versions.

I will be updating pdf-triage and pdf-metadata to also allow you to specify the folder to process, and where to save the output. I may even incorpoate those into this main script so that you only need to run one script and get everything, or select certain processing options.

# pdf-processing.sh
Script to process a PDF file

Command line options:

-f <filename.pdf>   # this option is required. You must provide the filename of the PDF using the -f switch.  
-v                  # this option prints the version and exits  
-p true/false  

The -p switch allows you to tell the script to not attempt to extract prior versions. This is most likely going to be used if you extract prior versions of a PDF, and then want to run the script against those version. You won't need to re-extract the prior versions of those earlier versions. That would be redundant. You can set this to false so that it skips that part. If you do not specify this flag and prior versions exist, the script will alert you of that and ask if you want to recover them.

Tested on Kali Linux 2023.1 and Kali Linux on WSL.

If running on Kali Linux WSL, you will need to run the following:

```
sudo apt update
sudo apt upgrade
sudo apt install exiftool
sudo apt install xpdf
sudo apt install pdf-parser
sudo apt install poppler-utils
sudo apt install pdfid

```
The script will execute the following processes against the PDF:
1. pdfinfo
2. exiftool
3. pdfimages
4. pdfsig
5. pdfid
6. pdf-parser
7. pdffonts
8. pdfdetach

The script will also attempt to carve out prior versions of the PDF by looking for %%EOF markers in the PDF. When you edit a PDF, the edits are added after the %%EOF, and a new %%EOF is added at the new file ending. This means there is an opportunity to extract prior versions of a PDF. It's not guaranteed, as there are factors that can cause prior versions to be invalid PDFs. It will depend on whether the tool that was used to edit the PDF is compliant with the PDF standard, whether there was some compressing (cleaning up) done by removing an earlier edit (but the %%EOF remains allowing you to at least know a prior version existed).

# pdf-triage.sh
Note: 
For the pdf-triage.sh script, you only need exiftool and xpdf from the above, plus the "file" command. If you've already installed exiftool and xpdf for the above script, you only need to install the file command here.
```
sudo apt install exiftool
sudo apt install xpdf
sudo apt install file
```
# pdf-metadata.sh
The pdf-metadata.sh script is really just packaging the exiftool command for the convenience of those who are unfamiliar with exiftool and its switches. You can run the exiftool command alone within the script and yield the same results (of course you need to provide a proper outoupt file in that case rather than the variable name used in the script).

For the pdf-metadata.sh script, you only need exiftool installed. If you already installed it for either of the above two scripts, you don't need to install it again here.
```
sudo apt install exiftool
```
