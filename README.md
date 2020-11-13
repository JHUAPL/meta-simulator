# Metagenomics Evaluation & Testing Analysis (META) Simulator

Compares open-source metagenomic classification tool performance (precision, sensitivity, runtime) across various 
sequencing platforms ([Illumina MiSeq/iSeq](https://www.illumina.com/), [Oxford Nanopore MinION](https://nanoporetech.com/)) and use cases
 (metagenomic profiles).

## Summary

  - [Getting Started](#getting-started)
  - [Running](#running)
  - [License](#license)

## Getting Started

These instructions will get you a copy of the project up and running on
your local machine for development and testing purposes. 

### Prerequisites

The META system has been designed to run on Linux (specifically, tested on Ubuntu 18.04) and in Docker containers. 
The following packages are required:

* [Docker-ce 19.03](https://docs.docker.com/engine/)

Here is an example of how to install these on Ubuntu 18.04:

```bash
# Install Docker engine (reference: https://docs.docker.com/engine/install/ubuntu/)
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
sudo docker run hello-world # to verify successful install
```

### Installing

To build the META Simulator, run the following from the root directory of `meta_simulator`:
```bash
docker build -t meta_simulator:latest .
```

### Integrating with Docker-based Meta System 

To integrate the META simulator with the Docker-based Meta System, you will need to export the meta_simulator into a docker tarfile and save it in the `meta_system/data/docker` directory.

1. To export the meta_simulator, run the following command:
    ```bash
    docker save -o meta_simulator.tar meta_simulator:latest
    ```
2. Move `meta_simulator.tar` to `meta_system/data/docker`
3. To make sure it loads on `meta_system` run `make load-docker` on `meta_system`

## Running

The META Simulator requires an abundance profile TSV. An *abundance profile* is expressed as a tab-delimited text file (TSV) where the first column contains the leaf taxonomic ID, the second column contains the corresponding abundance proportion (must sum to 1.000000), and the third column designates the organism as being foreground (`1`) or background (`0`). There should be no headers in the abundance profile TSV. An example is shown below:
```TSV
400667	0.10	1
435590	0.10	1
367928	0.10	1
864803	0.10	1
1091045	0.10	1
349101	0.10	1
1282	0.10	1
260799	0.10	1
1529886	0.10	1
198094	0.10	1
```
An example TSV is included within the Docker container in `data/test/strawman_envassay.tsv`.

The META Simulator accepts the following arguments:

* `-t` number of threads to use for simulations
* `-i` list of taxid with associated abundance (totalling 1.0)
* `-p` sequencing platform to simulate reads for (case sensitive)
    * The options are:
        * `iseq` Illumina iSeq 100
        * `miseq` Illumina MiSeq (assuming both illumina platforms have spot count of 8M, and taking 1/100 of this) [80,000]
        * `r9` Oxford Nanopore R9 flowcell (MIN106) - best performance at 50Gbp output (will assume 20Gbp and 20kb avg read length = 1M reads) [10,000]
        * `flg` Oxford Nanopore Flongle flowcell (FLG001) - best performance at 2Gbp output (1/25 of r9) (assuming 10% of r9 output) [1,000]
* `-o` Output directory (combined fastq file for classification will be at `$outdir/simulated.fastq`)

### Deep Simulator
To run DeepSimulator ([Nanopore R9 flowcell](https://store.nanoporetech.com/us/flowcells/spoton-flow-cell-mk-i-r9-4.html)) using META Simulator, run:

```bash
docker run meta_simulator:latest bash scripts/sim_module_wrapper.sh -t 2 -i data/strawman_envassay.tsv -p r9 -o data/test
```

To run DeepSimulator ([Nanopore Flongle flowcell](https://store.nanoporetech.com/us/flowcells/flongle-flow-cell.html)) using META Simulator, run:

```bash
docker run meta_simulator:latest bash scripts/sim_module_wrapper.sh -t 2 -i data/strawman_envassay.tsv -p flg -o data/test
```

### InsilicoSeq
To run InsilicoSeq ([Illumina MiSeq](https://www.illumina.com/systems/sequencing-platforms/miseq.html)) using META Simulator, run:

```bash
docker run meta_simulator:latest bash scripts/sim_module_wrapper.sh -t 2 -i data/strawman_envassay.tsv -p miseq -o data/test
```

To run InsilicoSeq ([Illumina iSeq](https://www.illumina.com/systems/sequencing-platforms/iseq.html)) using META Simulator, run:
```bash
docker run meta_simulator:latest bash scripts/sim_module_wrapper.sh -t 2 -i data/strawman_envassay.tsv -p iseq -o data/test
```

If you wish to run the simulator with your own abundance profile, use the [Docker bind mount](https://docs.docker.com/storage/bind-mounts/) `-v` flag for `docker run
` to mount the volume containing your abundance profile TSV.

## License

This project is licensed under [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0).
Copyright under Johns Hopkins University Applied Physics Laboratory.
