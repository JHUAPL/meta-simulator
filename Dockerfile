# docker build -t meta_simulator:latest .

FROM python:3.8-slim

# Explicit User (top of file to avoid conflicts down the line with IDs)
# Number should be same as meta_system to prevent conflicts...
ENV APP_USER simulator
ENV APP_WORK_DIR /home/${APP_USER}
ENV CONDA_VERSION 2020.07
RUN groupadd -r -g 999 ${APP_USER} && useradd -m -r -g ${APP_USER} -u 999 ${APP_USER}

# https://github.com/tianon/gosu/releases
# https://github.com/krallin/tini
RUN set -eux; \
    apt-get update; \
    apt-get install -y gosu tini; \
    rm -rf /var/lib/apt/lists/*; \
    gosu nobody true

# Install System Level Dependencies (Scripts, Simulator, guppy basecaller)
RUN set -eux; \
    apt-get update; \
    apt-get install -y libgl1-mesa-glx libegl1-mesa libxrandr2 libxrandr2 libxss1 libxcursor1 libxcomposite1 libasound2 libxi6 libxtst6; \
    apt-get install --no-install-recommends -y bc git wget curl gawk gzip parallel build-essential libidn11; \
    rm -rf /var/lib/apt/lists/*

# Setup Conda
# https://docs.anaconda.com/anaconda/install/linux/
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH
RUN set -eux; \
    mkdir -p /opt/conda; \
    chown ${APP_USER}:${APP_USER} /opt/conda; \
    gosu ${APP_USER} wget --quiet https://repo.anaconda.com/archive/Anaconda3-${CONDA_VERSION}-Linux-x86_64.sh -O ${APP_WORK_DIR}/anaconda.sh; \
    gosu ${APP_USER} /bin/bash ${APP_WORK_DIR}/anaconda.sh -b -u -p /opt/conda; \
    rm ${APP_WORK_DIR}/anaconda.sh; \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# Copy code to working directory
COPY --chown=${APP_USER}:${APP_USER} scripts ${APP_WORK_DIR}/scripts/
COPY --chown=${APP_USER}:${APP_USER} data/iss_model_iSeq_min120.npz ${APP_WORK_DIR}/data/iss_model_iSeq_min120.npz
COPY --chown=${APP_USER}:${APP_USER} data/strawman_envassay.tsv ${APP_WORK_DIR}/data/strawman_envassay.tsv
COPY --chown=${APP_USER}:${APP_USER} environment.yml ${APP_WORK_DIR}

# Switch User (this is fine for now because volumes mounted are 999 writable)
USER ${APP_USER}

# Tune Working Directory
WORKDIR ${APP_WORK_DIR}

# Install Conda dependencies for META Simulator
RUN set -eux; \
    echo ". /opt/conda/etc/profile.d/conda.sh" | tee -a ~/.bashrc; \
    echo "conda activate base" | tee -a ~/.bashrc; \
    . /opt/conda/etc/profile.d/conda.sh; \
    conda env create -f environment.yml

# Run install script for DeepSim, change permissions of shell files
RUN set -eux; \
    . /opt/conda/etc/profile.d/conda.sh; \
    conda activate simulator; \
    chmod +x scripts/sim_module_wrapper.sh; \
    chmod +x scripts/install.sh; \
    ${APP_WORK_DIR}/scripts/install.sh

# Install other dependencies for DeepSim
RUN set -eux; \
    . /opt/conda/etc/profile.d/conda.sh; \
    conda activate tensorflow_cdpm; \
    pip install tensorflow==1.2.1; \
    pip install tflearn==0.3.2; \
    pip install tqdm==4.19.4; \
    pip install scipy==0.18.1; \
    pip install h5py==2.7.1; \
    pip install numpy==1.13.1; \
    pip install scikit-learn==0.20.3; \
    pip install biopython==1.74

# Enable Process Ripper
ENTRYPOINT ["/usr/bin/tini", "--"]


