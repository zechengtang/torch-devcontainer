# This file is used to build the development container for the project.
# Use CUDA devel image without CUDNN since PyTorch brings its own CUDNN
ARG CUDA_VERSION=12.9.0
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04

# Install common apt dependencies as root user
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Hong_Kong
ARG UBUNTU_MIRROR=https://mirrors.bfsu.edu.cn/ubuntu/
RUN sed -i "s|http://archive.ubuntu.com/ubuntu/|$UBUNTU_MIRROR|g" /etc/apt/sources.list && \
    sed -i "s|http://security.ubuntu.com/ubuntu/|$UBUNTU_MIRROR|g" /etc/apt/sources.list
RUN apt-get update -y && \
    apt-get -y install --no-install-recommends curl tree wget ca-certificates unzip bzip2 xz-utils zip nano vim-tiny less jq lsb-release apt-transport-https sudo tmux ffmpeg libsm6 libxext6 libxrender-dev libssl3 git git-lfs gdb rsync aria2 && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG USER_NAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN addgroup --gid ${USER_GID} ${USER_NAME} && \
    adduser --disabled-password --gecos "" --uid ${USER_UID} --gid ${USER_GID} ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME}
USER ${USER_NAME}

# Install the uv package manager for the user
ARG PYPI_MIRROR=https://mirrors.aliyun.com/pypi/simple/
ENV PATH="/home/${USER_NAME}/.local/bin:${PATH}"
ENV UV_DEFAULT_INDEX=${PYPI_MIRROR}
ENV UV_LINK_MODE=copy
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes && \
    echo 'eval "$(starship init bash)"' >> /home/${USER_NAME}/.bashrc

# Install cmake and ninja globally with uv
RUN uv tool install cmake --no-cache && \
    uv tool install ninja --no-cache

# Configure runtime environments
ARG HUGGINGFACE_MIRROR=https://hf-mirror.com
ENV HF_ENDPOINT=${HUGGINGFACE_MIRROR}
ENV HF_HUB_DISABLE_XET=1

# Optional environment variables
# Allow nvenc capabilities for ffmpeg
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
# Disable NCCL P2P and IB to avoid issues with consumer-grade GPUs
# ENV NCCL_P2P_DISABLE=1 NCCL_IB_DISABLE=1
# Fine-tune the number of threads for OMP
# ENV OMP_NUM_THREADS=8

# Configure volumes for the user
RUN mkdir -p /home/${USER_NAME}/.cache/huggingface && \
    mkdir -p /home/${USER_NAME}/.cache/uv && \
    mkdir -p /home/${USER_NAME}/.cache/torch/hub
VOLUME ["/home/${USER_NAME}/.cache/huggingface", "/home/${USER_NAME}/.cache/uv", "/home/${USER_NAME}/.cache/torch/hub", "/home/${USER_NAME}/.local/share/uv"]
