#!/bin/bash

#  **********************************************************************
#  Copyright (C) 2020 Johns Hopkins University Applied Physics Laboratory
#
#  All Rights Reserved.
#  For any other permission, please contact the Legal Office at JHU/APL.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  **********************************************************************

#	FUNCTIONS
usage()
{
cat << EOF

Help message for remapOxfordFastq.sh:

	DESCRIPTION

NOTES:
	- WARNING:


USAGE:
bash scripts/remapOxfordFastq.sh -i data/fullDeepSim/metasim-strawman_envassay.tsv/r9/ -o pass_mapped.fastq


OPTIONS:
	-h      help		show this message
	-i      FASTQ		Input fastq containing directory from sim_module deepsim script run
	-o 	FASTQ	 	output fastq with mapped (3rd column) as runid


NOTES:
	This script requires the input to be the metasim output folder at first depth/child (40067, 1282, etc.) where each accession/seq header is a folder within those with the pass.fastq file in that

____________________________________________________________________________________________________
References:
	1. O. Tange (2011): GNU Parallel - The Command-Line Power Tool, ;login: The USENIX Magazine, February 2011:42-47.

EOF
}




#	ARGUMENTS
# parse args
while getopts "ho:i:" OPTION
do
	case $OPTION in
		h) usage; exit 1 ;;
		o) output_file=$OPTARG ;;
		i) INPUT=$OPTARG ;;
		?) usage; exit ;;
	esac
done
# check args
if [[ -z "$INPUT" ]]; then printf "%s\n" "Please specify input directory containing fasta file headers as directory with deepsim output (pass.fastq) (-i)."; exit; fi
if [[ -z "$output_file" ]]; then printf "%s\n" "Please specify output filename in the same directory as the pass.fastq file (-o)."; exit; fi
if [[ "$output_file" == "pass.fastq" ]]; then printf "%s\n" "Please specify output file name different than the pass.fastq filename."; exit; fi

for file in $(find $INPUT -maxdepth 5 -name "pass.fastq"); do # Not recommended, will break on whitespace
    dir=$(dirname $file)
    baseDir=$(basename $dir)
	# echo $dir $baseDir
	awk -v name=$baseDir 'BEGIN{li=0; inc=0;}{if( NR%4 == 1 ) {++li; print "@"name"_"li}else{print}}' $file > $dir"/"$output_file
	#awk -v name=$baseDir 'BEGIN{li=0; inc=0;}{if( NR%4 == 1 ) {++li; print "@"name"_"li}}' $file


done
