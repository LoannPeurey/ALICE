import os
import sys
import glob
#print(sys.argv[1])

if(len(sys.argv) < 2): # No extra arguments, use default input and output files
    raise Exception('Input file or folder not specified.')

curdir =  sys.argv[1]
file_list = sys.argv[2]

wasdir = 0
# Check that input exists
if(os.path.isdir(file_list)):
    fileList = sorted(glob.glob(file_list + '*.rttm'))
    wasdir = 1
    if(len(fileList) == 0):
        raise Exception('Provided directory contains no .rttm files')
elif(file_list.endswith('.rttm')):
    fileList = list()
    fileList.append(file_list)
    if not(os.path.isfile(fileList[0])):
        raise Exception('Provided input file does not exist.')
else:
    if(os.path.isfile(file_list)):
        fileList = list(filter(bool,[line.rstrip('\n') for line in open(file_list)]))
    else:
        raise Exception('Provided input file list does not exist.')

# Copy target files to a folder
outf = curdir + '/output_voice_type_classifier/tmp_data/all.rttm'
# outf = curdir + '/out/all.rttm'
with open(outf,'w') as outfile:
    for file in fileList:
        with open(file) as infile:
            for line in infile:
                outfile.write(line)


# for file in fileList:
#     path, filename = os.path.split(file)
#     copyfile(file,curdir + '/tmp_data/' + filename)
