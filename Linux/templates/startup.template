#!/bin/bash

# Start ComfyUI in the background
cd /ComfyUI
nohup python main.py --listen 0.0.0.0 > /var/log/comfyui.log 2>&1 &
echo "ComfyUI started on port 8188"

# Start Jupyter Lab
cd /notebooks
echo "Starting Jupyter Lab on port 8888"
jupyter lab --allow-root --no-browser --ip=0.0.0.0 --port=8888