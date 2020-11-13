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

usage()
{
cat << EOF

	DESCRIPTION: This script will run deep simulator using either CPU or GPU to make a set of reads for a single fasta file. Future Updates below

USAGE:
	bash simulate.sh -i absolute path to fasta file
	-c number of cpu nodes you want
	-n Number of reads for simulation
	-g [CPU/GPU/ALBACORE]
	-o <Output Directory that should be the name of the file you want/organism you want to simulate
OPTIONS:
	-h      help		show this message
	-i      fna		reference fasta input file
	-n	read#	 	number of reads for given fasta file
	-o 	output		output directory
	-g 	GPU/CPU		Choose either CPU or GPU to run simulation on
	-j  exit at fast5 [1|2] where 1 is default and it doesnt exit and 2 exits after fast5 making
NOTES:
	Update this script is in the works to map abundance profile to a directory of fasta files

EOF
}
source activate simulator

# parsing arguments from command line
cpu_count=1
deep_sim_loc="$PWD/src/DeepSimulator"
guppy_type="CPU"
read_count=1
j=1
while getopts "hi:d:o:n:B:c:r:g:j:" OPTION
do
	case $OPTION in
		h) usage; exit 1 ;;
		i) fasta_input_file=$OPTARG ;;
		o) output_dir=$OPTARG ;;
		c) cpu_count=$OPTARG ;;
		g) guppy_type=$OPTARG ;;
		d) deep_sim_loc=$OPTARG;;
		n) read_count=$OPTARG;;
		j) j=$OPTARG;;
		?) usage; exit ;;
	esac
done

if [[ (! $guppy_type == "GPU" ) && (! $guppy_type == "CPU") && (! $guppy_type == "ALBACORE") ]]; then
	usage
	echo "Invalid Guppy basecaller selected [GPU|CPU|ALBACORE]. Exiting."
	exit 1
fi
echo $guppy_type
if [[ $guppy_type == "GPU" ]]; then
	guppy_type=1
elif [[ $guppy_type == "CPU" ]]; then
	guppy_type=2
else
	guppy_type=3
fi

#define location of fasta input and output location of simulated reads as user
#since torque runs the script from a different location, specify absolute pathing
current_loc=$( pwd )
envbin=$(which python)
base="$(dirname $envbin)"
echo $deep_sim_loc
echo $PWD

base=$(basename ${fasta_input_file} .fasta)
mkdir $output_dir"/$base"
conda deactivate
if [[ $j -eq 1 ]]; then
	echo $output_dir"/$base"
cat <<EOF
${deep_sim_loc}/deep_simulator.sh \
-i ${fasta_input_file} \
-n ${read_count} \
-c $cpu_count \
-o $output_dir"/$base" \
-B $guppy_type \
-H $deep_sim_loc
EOF
	bash ${deep_sim_loc}/deep_simulator.sh \
	-i ${fasta_input_file} \
	-n ${read_count} \
	-c $cpu_count \
	-o $output_dir"/$base" \
	-B $guppy_type \
	-H $deep_sim_loc
	# exit 1

elif [[ $j -eq 2 ]]; then
cat <<EOF
${deep_sim_loc}/deep_simulator_fast5only.sh \
-i ${fasta_input_file} \
-n ${read_count} \
-c $cpu_count \
-o $output_dir"/$base" \
-B $guppy_type \
-H $deep_sim_loc
EOF
	bash ${deep_sim_loc}/deep_simulator_fast5only.sh \
	-i ${fasta_input_file} \
	-n ${read_count} \
	-c $cpu_count \
	-o $output_dir"/$base" \
	-B $guppy_type \
	-H $deep_sim_loc
	# exit 1
else
	echo "Exit: -j isn't properly specified as 1 (dont exit after fast5) or 2 (exit after fast5)"
	exit 1
fi






#After the fun is done for the fullDeepSim run

# bash scripts/remapOxfordFastq.sh \
# -i data/fullDeepSim/metasim-strawman_envassay.tsv/r9/ \
# -o pass_mapped.fastq && find data/fullDeepSim/metasim-strawman_envassay.tsv/r9/ \
# -maxdepth 3 \
# -name "pass_mapped.fastq" \
# -exec cat {} + > data/fullDeepSim/pass_mapped_merged.fastq

