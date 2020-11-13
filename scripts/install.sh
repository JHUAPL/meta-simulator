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

####Define ENV variables
run_dir=$PWD
g="$(which python)"
baseBin=$(dirname ${g})
src_bin="${run_dir}/src"
mkdir $src_bin
CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"
script_location="$(perl -MCwd=abs_path -le 'print abs_path(shift)' $(which $(basename $0)))"
##########Install DeepSimulator##########################################
git clone https://github.com/lykaust15/DeepSimulator.git $src_bin/DeepSimulator
cd $src_bin/DeepSimulator
find "$PWD" -name "*download*.sh" -print0 | while read -d $'\0' fn; do sed -Ei "s/source activate/conda activate/g" $fn ; done
find "$PWD" -name "*install.sh" -print0 | while read -d $'\0' fn; do sed -Ei "s/source activate/conda activate/g" $fn ; done
find "$PWD" -name "*install.sh" -print0 | while read -d $'\0' fn; do sed -Ei "s/source deactivate/conda deactivate/g" $fn ; done
echo $PWD
grep -q "source $CONDA_BASE/etc/profile.d/conda.sh" install.sh
if [[ $? != 0 ]] ; then
	echo "source $CONDA_BASE/etc/profile.d/conda.sh" | cat - install.sh > temp && mv temp install.sh
fi
bash install.sh
#-> 2. install basecaller
#--| 2.1 install albacore_2.3.1
cd base_caller/albacore_2.3.1/
	./download_and_install.sh
cd ../../

#--| 2.2 install guppy_3.1.5
cd base_caller/guppy_3.1.5/
	./download_and_install.sh
cd ../../

cd $run_dir

#######Ont guppy upgrade to 3.4.5########################################
wget https://americas.oxfordnanoportal.com/software/analysis/ont-guppy-cpu_3.4.5_linux64.tar.gz -P src/

mkdir $src_bin/DeepSimulator/base_caller/guppy_3.4.5
tar -xvzf src/ont-guppy-cpu_3.4.5_linux64.tar.gz --directory $src_bin/DeepSimulator/base_caller/guppy_3.4.5

rm -rf src/ont-guppy-cpu_3.4.5_linux64.tar.gz


#Enable fast mode (less accurate) for cpu basecalling
sed -Ei "s/hac/fast/g" $src_bin/DeepSimulator/deep_simulator.sh
sed -Ei "s/guppy=guppy_3\.[0-9]*\.[0-9]*/guppy=guppy_3\.4\.5/g" $src_bin/DeepSimulator/deep_simulator.sh
sed -Ei "s/source deactivate/conda deactivate/g" $src_bin/DeepSimulator/deep_simulator.sh

#Create a new deepsim script that exits early i.e. there is no basecalling. It only makes fast5 files
cp $src_bin/DeepSimulator/deep_simulator.sh $src_bin/DeepSimulator/deep_simulator_fast5only.sh
sed -Ei "s/guppy=guppy_3\.[0-9]*\.[0-9]*/exit 1/g" $src_bin/DeepSimulator/deep_simulator_fast5only.sh


#Symlink the two files into the conda environment bin folder
ln -sf $src_bin/DeepSimulator/deep_simulator.sh\
 $baseBin/
ln -sf $src_bin/DeepSimulator/deep_simulator_fast5only.sh\
 $baseBin/


#because albacore doesnt work in the deepsim install script, redo it
source activate basecall
wget https://mirror.oxfordnanoportal.com/software/analysis/ont_albacore-2.3.1-cp36-cp36m-manylinux1_x86_64.whl \
-P $src_bin/
pip install $src_bin/ont_albacore-2.3.1-cp36-cp36m-manylinux1_x86_64.whl
rm $src_bin/*albacore*
