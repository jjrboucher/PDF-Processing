# PDF-Processing
Script to process PDF files

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
#pdf-triage.sh
Note: 
For the pdf-triage.sh script, you only need exiftool and xpdf from the above, plus the "file" command: 
```
sudo apt install file
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

# pdf-metadata.sh
The pdf-metadata.sh script is really just packaging the exiftool command for the convenience of those who are unfamiliar with exiftool and its switches. You can run the exiftool command alone within the script and yield the same results (of course you need to provide a proper outoupt file in that case rather than the variable name used in the script).
