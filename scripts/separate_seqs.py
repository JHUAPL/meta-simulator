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

import sys
import argparse
import csv

##########################Take in Args######################################################
parser = argparse.ArgumentParser(description = "Parse a fasta file and retrieve random set of short sequences (cut up from FASTA, can be multiline) ")
parser.add_argument('-i', required = True, type=str, nargs='+', help = 'Input FASTA file, can containing multiple fastas ')
parser.add_argument('-n', required = True, type=str, nargs='+', help = 'Number of total reads you want')
parser.add_argument('-o', required = True, type=str, nargs='+', help = 'Output dir')


args = parser.parse_args()
##############################################################
from Bio import SeqIO
count = 0
for seq_record in SeqIO.parse(vars(args)['i'][0], "fasta"):
	count += len(seq_record.seq)
for seq_record in SeqIO.parse(vars(args)['i'][0], "fasta"):
	# print(str(seq_record.seq))

	fp = open(vars(args)['o'][0]+"/"+seq_record.id+".fasta","w")
	fp.write(">"+seq_record.id+"\n"+str(seq_record.seq))
	fp.close()
