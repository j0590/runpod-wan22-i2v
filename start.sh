#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/venv/bin:$PATH"
export WORKDIR=/workspace/ComfyUI
export COMFYUI_ARGS="${COMFYUI_ARGS:---listen 0.0.0.0 --port 8188}"
mkdir -p /workspace
if [ ! -d "$WORKDIR" ]; then cp -a /ComfyUI "$WORKDIR"; fi
mkdir -p "$WORKDIR/custom_nodes" "$WORKDIR/models/diffusion_models" "$WORKDIR/models/clip" "$WORKDIR/models/vae" "$WORKDIR/models/loras" "$WORKDIR/models/upscale_models" "$WORKDIR/user/default/workflows"
if [ -f /moeksampler.json ]; then cp -f /moeksampler.json "$WORKDIR/user/default/workflows/moeksampler.json"; fi
cd "$WORKDIR/custom_nodes"
repos=(https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git https://github.com/kijai/ComfyUI-KJNodes.git https://github.com/rgthree/rgthree-comfy.git https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git https://github.com/Jordach/comfy-plasma.git https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git https://github.com/bash-j/mikey_nodes.git https://github.com/ltdrdata/ComfyUI-Impact-Pack.git https://github.com/Fannovel16/comfyui_controlnet_aux.git https://github.com/yolain/ComfyUI-Easy-Use.git https://github.com/kijai/ComfyUI-Florence2.git https://github.com/ShmuelRonen/ComfyUI-LatentSyncWrapper.git https://github.com/WASasquatch/was-node-suite-comfyui.git https://github.com/theUpsider/ComfyUI-Logic.git https://github.com/cubiq/ComfyUI_essentials.git https://github.com/chrisgoringe/cg-image-picker.git https://github.com/chflame163/ComfyUI_LayerStyle.git https://github.com/chrisgoringe/cg-use-everywhere.git https://github.com/kijai/ComfyUI-segment-anything-2.git https://github.com/welltop-cn/ComfyUI-TeaCache.git https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git https://github.com/Jonseed/ComfyUI-Detail-Daemon.git https://github.com/kijai/ComfyUI-WanVideoWrapper.git https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git https://github.com/BadCafeCode/masquerade-nodes-comfyui.git https://github.com/1038lab/ComfyUI-RMBG.git https://github.com/M1kep/ComfyLiterals.git https://github.com/princepainter/ComfyUI-PainterI2V.git https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git https://github.com/ssitu/ComfyUI-FBCNN.git)
for repo in "${repos[@]}"; do repo_dir=$(basename "$repo" .git); if [ -d "$repo_dir/.git" ]; then cd "$repo_dir" && git pull && cd ..; else git clone "$repo"; fi; if [ -f "$repo_dir/requirements.txt" ]; then pip install -r "$repo_dir/requirements.txt"; fi; if [ -f "$repo_dir/install.py" ]; then python "$repo_dir/install.py"; fi; done
dl(){ url="$1"; out="$2"; if [ -f "$out" ]; then echo "OK: $out"; else aria2c -x16 -s16 -k1M -o "$(basename "$out")" -d "$(dirname "$out")" "$url"; fi }
dltoken(){ url="$1"; out="$2"; hdr="$3"; if [ -f "$out" ]; then echo "OK: $out"; else curl -L -H "$hdr" "$url" -o "$out"; fi }
dl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors" "$WORKDIR/models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_v2.0.safetensors"
dl "https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors" "$WORKDIR/models/diffusion_models/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_v2.0.safetensors"
dl "https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" "$WORKDIR/models/clip/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
dl "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/3902f61b9647e65d4de4fb5febad34ca0e4dc5c8/split_files/vae/wan_2.1_vae.safetensors" "$WORKDIR/models/vae/wan_2.1_vae.safetensors"
if [ ! -f "$WORKDIR/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth" ]; then gdown --id 1-pC6_7Lrmy3p-VAh-dGzvETRBUUAQzmV -O "$WORKDIR/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth"; fi
if [ -n "${civitai_token:-}" ]; then dltoken "https://civitai.com/api/download/models/2073605" "$WORKDIR/models/loras/nsfwsks_high.safetensors" "Authorization: Bearer ${civitai_token}"; dltoken "https://civitai.com/api/download/models/2083303" "$WORKDIR/models/loras/nsfwsks_low.safetensors" "Authorization: Bearer ${civitai_token}"; fi
cd "$WORKDIR"
python main.py $COMFYUI_ARGS
