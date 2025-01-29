FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    git \
    python3.10 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /

RUN git clone https://github.com/comfyanonymous/ComfyUI.git
WORKDIR /ComfyUI

RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
RUN pip3 install -r requirements.txt

# Create directory for custom node installation scripts
RUN mkdir -p /setup_scripts
COPY scripts/* /setup_scripts/
RUN chmod +x /setup_scripts/*

# Execute all setup scripts
RUN if [ -n "$(ls -A /setup_scripts/)" ]; then \
        for script in /setup_scripts/*; do \
            if [ -f "$script" ] && [ -x "$script" ]; then \
                $script; \
            fi; \
        done; \
    fi

EXPOSE 8188

CMD python3 main.py --listen 0.0.0.0 --port 8188