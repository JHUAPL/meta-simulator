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

Help message for sim_module:

	DESCRIPTION

NOTES:
	- WARNING:


USAGE:
	bash sim_module_wrapper.sh -i </absolute/path/to/taxa_abundance_profile.tsv>

bash scripts/sim_module_wrapper.sh -t 10 -i data/test.tsv -p iseq


OPTIONS:
	-h      help		show this message
	-H      STR		Home directory specification for the sim_module_wrapper.sh file (OPTIONAL)
	-t		INT		number of threads to use for simulations
	-i      TSV		list of taxid with associated abundance (totalling 1.0)
					TAXID can be at any taxonomic level, however the first accession
					found when searching the 'taxid' column of "assembly_summary_refseq.txt"
					will be used as the reference for simulating reads
	-p		STR	    sequencing platform to simulate reads for (case sensitive)
					available options [total reads simulated]:
						iseq	Illumina iSeq 100 (assuming both illumina platforms have spot count of 8M, and taking 1/100 of this) [80,000]
						miseq	Illumina MiSeq [80,000]
						r9		Oxford Nanopore R9 flowcell (MIN106) - best performance at 50Gbp output (will assume 20Gbp and 20kb avg read length = 1M reads) [10,000]
						flg		Oxford Nanopore Flongle flowcell (FLG001) - best performance at 2Gbp output (1/25 of r9) (assuming 10% of r9 output) [1,000]
				    pending options:
						r10		Oxford Nanopore R10 flowcell (MIN107)   <- not implemented
	-j 		INT 	If using Deep Simulator (r9,flg) specify if you want to only generate fast5 files.
					Available Options:
						1	Full process from fast5 generation to fastq/basecalling
						2 	Exit early. Generated only fast5 files
	-o      DIR     Output directory (combined fastq file for classification will be at "$outdir/simulated.fastq")


NOTES:
	Input abundance profile (abundance based on proportion bps of reads, not genome size)

____________________________________________________________________________________________________
References:
	1. O. Tange (2011): GNU Parallel - The Command-Line Power Tool, ;login: The USENIX Magazine, February 2011:42-47.

EOF
}




#	ARGUMENTS
# parse args
while getopts "ht:i:p:r:j:H:o:" OPTION
do
	case $OPTION in
		h) usage; exit 1 ;;
		t) THREADS=$OPTARG ;;
		i) INPUT=$OPTARG ;;
		p) PLATFORM=$OPTARG ;;
		H) HOME_DIR=$OPTARG ;;
		r) READSCOUNT=$OPTARG;;
		j) r9cfg=$OPTARG;;
		o) OUTPUT=$OPTARG;;
		?) usage; exit ;;
	esac
done
# check args
if [[ -z "$THREADS" ]]; then printf "%s\n" "Please specify number of threads (-t)."; exit; fi
if [[ -z "$INPUT" ]]; then printf "%s\n" "Please specify input tsv (-i)."; exit; fi
if [[ -z "$PLATFORM" ]]; then printf "%s\n" "Please specify sequencing platform (-p)."; exit; fi
#if [[ -z $READSCOUNT ]]; then READSCOUNT=10000; fi;    # 20200520, readcount will be based on platform type
if [[ -z $HOME_DIR ]]; then HOME_DIR=$PWD; fi
if [[ -z $r9cfg ]]; then r9cfg=1; fi
if [[ -z $OUTPUT ]]; then printf "%s\n" "Please specify a final output directory (-o)."; exit; fi
if [[ ! -d "$OUTPUT" ]]; then mkdir -p "$OUTPUT"; fi

#Activate the correct environment for simulator (iss and deepsim)


# setup other variables
absolute_path_x="$(readlink -fn -- "$0"; echo x)"
absolute_path_of_script="${absolute_path_x%x}"
scriptdir=$(dirname "$absolute_path_of_script")
runtime=$(date +"%Y%m%d%H%M%S%N")
dn=$(dirname "$INPUT")
bn=$(basename "$INPUT")
#outdir="$dn/metasim-$bn"
outdir="$OUTPUT"
tmp="$outdir/tmp"
if [[ ! -d "$tmp" ]]; then
    mkdir -p "$tmp"
fi


#	MAIN
echo "Checking that abundance profile sums to 1.000000 (input.tsv column 2)."
check=$(awk -F'\t' '{x+=$2}END{printf("%f",x)}' "$INPUT" | cut -c1-8)
if [[ "$check" != "1.000000" ]]; then
	echo "Input abundances sum to $check"
	echo "They must sum to 1 within a tolerance of <1 millionth (i.e. 1.000000). Exiting."; exit
else
	echo "Check successful."
fi
# get updated assembly summary refseq (asr)
echo "Pulling latest 'assembly_summary_refseq.txt files."
asr="$tmp/assembly_summary_refseq.txt"
for k in "archaea" "bacteria" "fungi" "invertebrate" "other" "plant" "protozoa" "vertebrate_mammalian" "vertebrate_other" "viral"; do
	echo "downloading refseq summary for $k"
	if [[ ! -f "$asr.tmp-$k" ]]; then
		wget ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/$k/assembly_summary.txt --output-document "$asr.tmp-$k"
	fi
done 2> /dev/null
#	combine all
find "$tmp" -maxdepth 1 -name "*assembly_summary_refseq.txt.tmp-*" -exec cat {} + > "$asr"


asri="$tmp/asr_input.tsv"
awk -F'\t' '{if(FNR==NR){rs[$6]=$0}else{printf("%s\n",rs[$1])}}' "$asr" "$INPUT" > "$asri"
# check if any accession are missing from the overlap
#	find overlap between it and the input
check=$(comm -23 <(cut -f1 "$INPUT" | sort) <(cut -f6 "$asri" | sort))
if [[ "$check" != "" ]]; then
	echo "The following accessions did not have a corresponding"
	echo "path in the assembly summary refseq file:"
	echo "$check"
	echo "Please remove or subsitute the accession(s) above, and resubmit."; exit
fi


# pull ftp paths and download reference genomes for accessions in input tsv
#	1	assembly_accession
#	6	taxid				<- strain if available, otherwise is species taxid
#	7	species_taxid
#	8	organism_name
#	9	infraspecific_name
#	20	ftp_path
mkdir -p "$outdir/$PLATFORM"
while read x; do
	acc=$(printf "$x" | cut -f1)
	taxid=$(printf "$x" | cut -f6)
	name=$(printf "$x" | cut -f8)
	path=$(printf "$x" | cut -f20)
	bn=$(basename "$path")
	echo "	wgetting: $acc, $taxid, $name"



	wget "$path/${bn}_genomic.fna.gz" --output-document "$outdir/$taxid.fasta.gz" 2> /dev/null
	gunzip -f "$outdir/$taxid.fasta.gz"
	# put all sequence strings under each header into a single line
	awk '{if(NR == 1){printf("%s\n", $0)}else{if(substr($0,1,1) == ">"){printf("\n%s\n", $0)} else {printf("%s", $0)}}}END{printf("\n")}' "$outdir/$taxid.fasta" > "$outdir/$taxid.fasta.tmp"
	# only retain contigs/assemblies >1 Kbp
	sed $'$!N;s/\\\n/\t/' "$outdir/$taxid.fasta.tmp" | awk -F'\t' '{if(length($2)>=1000){printf("%s\n%s\n",$1,$2)}}' > "$outdir/$taxid.fasta"
	rm "$outdir/$taxid.fasta.tmp"




	abu=$(grep -P "^$taxid\t" "$INPUT" | cut -f2)
	# calculate number reads based on abundance in input and on:
	# ILLUMINA	(~4-8 million reads output), output 8 million reads
	#	MISEQ	2 x 150bp [80,000]
	#	ISEQ	2 x 150f [80,000]
	# OXFORD MINION (r9 ~20Gbp @ 20Kb avg read length), output 1 million reads
	#	R9		rapid library kit RAD004 [10,000]
	#	FLG		rapid library kit RAD004 [1,000]
	#	R10		ligation library kit LSK009 [n/a]


	#	InSilicoSeq
	#  --cpus <int>, -p <int>
	#                        number of cpus to use. (default: 2).
	#  --genomes <genomes.fasta> [<genomes.fasta> ...], -g <genomes.fasta> [<genomes.fasta> ...]
	#                        Input genome(s) from where the reads will originate
	#  --draft <draft.fasta> [<draft.fasta> ...]
	#                        Input draft genome(s) from where the reads will
	#                        originate
	#						If you have draft genome files containing contigs, you can give them to the --draft option:
	#  --n_reads <int>, -n <int>
	#                        Number of reads to generate (default: 1000000). Allows
	#                        suffixes k, K, m, M, g and G (ex 0.5M for 500000).
	#  --model <npz>, -m <npz>
	#                        Error model file. (default: None). Use HiSeq, NovaSeq
	#                        or MiSeq for a pre-computed error model provided with
	#                        the software, or a file generated with iss model. If
	#                        you do not wish to use a model, use --mode basic or
	#                        --mode perfect. The name of the built-in models are
	#                        case insensitive.
	#  --output <fastq>, -o <fastq>
	#                        Output file prefix (Required)

	if [[ "$PLATFORM" == "iseq" ]]; then
		count=$(printf "$abu" | awk '{printf("%.0f",$0*80000)}')
	    echo "Simulating $count reads for $taxid, $name, $PLATFORM, at abundance of $abu"
		model=$HOME_DIR"/data/iss_model_iSeq_min120.npz"
		source activate simulator
		iss generate -p "$THREADS" --draft "$outdir/$taxid.fasta" -n "$count" -m "$model" -o "$outdir/$PLATFORM/$taxid" 2> "$outdir/error.log"
	elif [[ "$PLATFORM" == "miseq" ]]; then
		count=$(printf "$abu" | awk '{printf("%.0f",$0*80000)}')
	    echo "Simulating $count reads for $taxid, $name, $PLATFORM, at abundance of $abu"
		model="MiSeq"
		source activate simulator
		iss generate -p "$THREADS" --draft "$outdir/$taxid.fasta" -n "$count" -m "$model" -o "$outdir/$PLATFORM/$taxid" 2> "$outdir/error.log"
	elif [[ "$PLATFORM" == "r9" || "$PLATFORM" == "flg" ]]; then

	    if [[ "$PLATFORM" == "r9" ]]; then
            # making r9 total reads default 10,000
		    count=$(printf "$abu" | awk '{printf("%.0f",$0*10000)}')
        elif [[ "$PLATFORM" == "flg" ]]; then
            # making flg total reads default 1,000
		    count=$(printf "$abu" | awk '{printf("%.0f",$0*1000)}')
	    fi

	    echo "Simulating $count reads for $taxid, $name, $PLATFORM, at abundance of $abu"
		r9ScriptLocation=$HOME_DIR"/scripts/"

		totalCountNucleotides=$( grep "^[^>]" "$outdir/$taxid.fasta" | tr -d "\n"  | wc -c )
		seqs=($( grep -R "^>" "$outdir/${taxid}.fasta" | tr " " "|" ))
		total=${#seqs[*]}
		if [ ! -d $r9ScriptLocation"../tmp" ]; then
			mkdir $r9ScriptLocation"../tmp"
		fi
		if [ -d $r9ScriptLocation"../tmp/seqs" ]; then
			rm -rf 	$r9ScriptLocation"../tmp/seqs"
		fi
		mkdir $r9ScriptLocation"../tmp/seqs/"
		if [ -d  $outdir/"$PLATFORM/$taxid" ]; then
			rm -rf $outdir/"$PLATFORM/$taxid"
		fi
		if [ ! -d  $outdir/"$PLATFORM/logs" ]; then
			mkdir $outdir/"$PLATFORM/logs"
		fi
		if [ -f "$outdir/$PLATFORM/logs/pythonLog.txt" ]; then
			rm "$outdir/$PLATFORM/logs/pythonLog.txt"
		fi
		if [ -f "$outdir/$PLATFORM/logs/simulationLog.txt" ]; then
			rm "$outdir/$PLATFORM/logs/simulationLog.txt"
		fi
		mkdir -p $outdir/$PLATFORM/$taxid
		source activate simulator
		python "$r9ScriptLocation/"separate_seqs.py -i $outdir/$taxid.fasta -o $r9ScriptLocation"../tmp/seqs/" -n "$count" >> "$outdir/$PLATFORM/logs/pythonLog.txt" 2>&1
		conda deactivate
		files=()
		while IFS=  read -r -d $'\0'; do
		    files+=("$REPLY")
		done < <(find ${r9ScriptLocation}"/../tmp/seqs/" -name "*.fasta" -print0)
		for (( i=0;  i < "${#files[@]}" ; i++ ))
		do
			length=$( grep -e '^[^>]' ${files[$i]} |  tr -d "\n" | wc -c )
			count_seq=$( echo "scale=20; 0.5+($count*$length)/$totalCountNucleotides" | bc -l | xargs printf %.0f )
			echo "count_seq equals $count_seq"
			bash "$r9ScriptLocation"/simulate.sh \
			-i ${files[$i]} \
			-n $count_seq \
			-o "$outdir/$PLATFORM/$taxid" \
			-c $THREADS \
			-g "CPU" \
			-d $HOME_DIR"/src/DeepSimulator" \
			-j $r9cfg

			find "$outdir/$PLATFORM/$taxid" -name "fast5" -type d -exec rm -rf  "{}" \;
		done >> "$outdir/$PLATFORM/logs/simulationLog.txt" 2>&1
		rm -rf 	${r9ScriptLocation}"/../tmp/seqs/*"
		echo "done with this file $outdir $taxid"


	fi
    # NOTES:
    #	name your output fastq per taxid with the taxid, such that "sed 's/_R.*//'" will return ONLY the taxid

done < "$asri"





if [[ "$PLATFORM" == "r9" || "$PLATFORM" == "flg" ]]; then
	echo "merging all $PLATFORM fastq files"
	bash "$HOME_DIR/scripts/remapOxfordFastq.sh" \
	-i "$outdir/$PLATFORM/" \
	-o "pass_mapped.fastq" && find "$outdir/$PLATFORM/" \
	-maxdepth 5 \
	-name "pass_mapped.fastq" \
	-exec cat {} + > $outdir"/simulated.fastq"
	mv "$outdir/simulated.fastq" "$OUTPUT/"
	rm -rf "$outdir/$PLATFORM"
elif [[ "$PLATFORM" == "iseq" || "$PLATFORM" == "miseq" ]]; then
	echo "fixing headers and combining fastqs"
	# rename headers for 'taxid'
	find "$outdir/$PLATFORM" -maxdepth 1 -name "*fastq" | while read fq; do
		bn=$(basename "$fq" | sed 's/_R.*//')
		sed $'$!N;s/\\\n/\t/' "$fq" | sed $'$!N;s/\\\n/\t/' | awk -v name="$bn" -F'\t' '{printf("@%s\n%s\n%s\n%s\n",name,$2,$3,$4)}' > "$fq.tmp"
	done
	# merge all fastq
	find "$outdir/$PLATFORM" -maxdepth 1 -name "*fastq.tmp" -exec cat {} + > "$outdir/$PLATFORM/fastq.merged"
	# rename headers for 'taxid-readID'
	sed $'$!N;s/\\\n/\t/' "$outdir/$PLATFORM/fastq.merged" | sed $'$!N;s/\\\n/\t/' | awk -F'\t' '{printf("%s-%s\n%s\n%s\n%s\n",$1,NR,$2,$3,$4)}' > "$outdir/simulated.fastq"
    mv "$outdir/simulated.fastq" "$OUTPUT/"
    rm -rf "$outdir/$PLATFORM"
fi




