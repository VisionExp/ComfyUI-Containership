FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /

RUN apt update && \
    apt upgrade -y && \
    apt install -y \
      python3-dev \
      python3-pip \
      fonts-dejavu-core \
      rsync \
      git \
      jq \
      moreutils \
      aria2 \
      wget \
      curl \
      libglib2.0-0 \
      libsm6 \
      libgl1 \
      libxrender1 \
      libxext6 \
      ffmpeg \
      libgoogle-perftools4 \
      libtcmalloc-minimal4 \
      procps \
      python3-opencv \
      build-essential \
      python3-venv \
      nvidia-cuda-toolkit && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean -y


RUN ln -s /usr/bin/python3.10 /usr/bin/python

RUN pip install --no-cache-dir git+https://github.com/huggingface/accelerate

RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

RUN pip install --no-cache-dir \
    opencv-python-headless==4.8.1.78 \
    pillow \
    transformers \
    safetensors \
    aiohttp \
    numpy \
    color-matcher

RUN pip install --no-cache-dir \
    jupyter \
    jupyterlab \
    notebook \
    ipywidgets

WORKDIR /home
RUN git clone https://github.com/comfyanonymous/ComfyUI.git

WORKDIR /home/ComfyUI
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
WORKDIR /
WORKDIR /home/ComfyUI/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git
WORKDIR /home/ComfyUI/custom_nodes/ComfyUI-Manager
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

RUN mkdir /root/.jupyter
RUN jupyter notebook --generate-config
RUN echo "c.NotebookApp.password = ''" >> /root/.jupyter/jupyter_notebook_config.py
RUN echo "c.NotebookApp.token = ''" >> /root/.jupyter/jupyter_notebook_config.py
RUN echo "c.NotebookApp.ip = '0.0.0.0'" >> /root/.jupyter/jupyter_notebook_config.py
RUN echo "c.NotebookApp.notebook_dir = '/home/ComfyUI'" >> /root/.jupyter/jupyter_notebook_config.py


EXPOSE 8188 8888

COPY startup.sh /startup.sh
RUN chmod +x /startup.sh