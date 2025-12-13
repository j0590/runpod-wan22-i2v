#!/usr/bin/env bash
set -Eeuo pipefail

ts() { date +"[%H:%M:%S]"; }
log() { echo "$(ts) $*"; }

# -------------------------
# Config (env overridable)
# -------------------------
WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_DIR="${COMFY_DIR:-$WORKSPACE/ComfyUI}"

# Persistent venv on volume
VENV_ROOT="${VENV_ROOT:-$WORKSPACE/venvs}"
VENV_NAME="${VENV_NAME:-py312-cu128}"
VENV_DIR="${VENV_DIR:-$VENV_ROOT/$VENV_NAME}"

# One-shot bootstrap sentinel
BOOTSTRAP_VERSION="v6"  # bump this when you intentionally change bootstrap behavior
SENTINEL="${SENTINEL:-$WORKSPACE/.bootstrap_done_${BOOTSTRAP_VERSION}_${VENV_NAME}}"

# Speed knobs
CLONE_JOBS="${CLONE_JOBS:-12}"
ARIA_CONN="${ARIA_CONN:-16}"

# Comfy args (fix common typo: -listen -> --listen)
COMFYUI_ARGS="${COMFYUI_ARGS:---listen 0.0.0.0 --port 8188}"
COMFYUI_ARGS="${COMFYUI_ARGS/-listen /--listen }"

# Caches on /workspace (fast reboot + recompile reuse)
CACHE_DIR="${CACHE_DIR:-$WORKSPACE/.cache}"
export XDG_CACHE_HOME="$CACHE_DIR"
export HF_HOME="$CACHE_DIR/huggingface"
export HUGGINGFACE_HUB_CACHE="$CACHE_DIR/huggingface/hub"
export TORCH_HOME="$CACHE_DIR/torch"
export TRITON_CACHE_DIR="$CACHE_DIR/triton"
export TORCHINDUCTOR_CACHE_DIR="$CACHE_DIR/torchinductor"
export PIP_CACHE_DIR="$CACHE_DIR/pip"
export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"

# -------------------------
# Helpers
# -------------------------
need_cmd() { command -v "$1" >/dev/null 2>&1 || { log "💥 Missing command: $1"; exit 1; }; }

python_ok() { python - <<'PY' >/dev/null 2>&1
import sys; sys.exit(0)
PY
}

pip_install() {
  python -m pip install --upgrade "$@"
}

aria_get() {
  # aria_get URL OUTFILE
  local url="$1"; local out="$2"
  if [ -f "$out" ]; then
    log "✅ Exists: $(basename "$out")"
    return 0
  fi
  log "⬇️ Downloading: $(basename "$out")"
  aria2c -x "$ARIA_CONN" -s "$ARIA_CONN" -k 1M --file-allocation=none \
    --allow-overwrite=true --auto-file-renaming=false \
    -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
  [ -f "$out" ] || { log "💥 Download failed: $url"; return 1; }
  log "✅ Downloaded: $(basename "$out")"
}

clone_repo() {
  # clone_repo NAME URL DESTDIR
  local name="$1"; local url="$2"; local dest="$3"
  if [ -d "$dest/.git" ]; then
    log "✅ Node exists: $name"
    return 0
  fi

  log "⬇️ Cloning node: $name"
  local tmp="${dest}.tmp.$$"
  rm -rf "$tmp"

  # Try fast shallow+partial clone first
  if git clone --depth 1 --filter=blob:none --single-branch "$url" "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$dest"
    log "✅ Cloned: $name"
    return 0
  fi

  # Fallback: zip download (avoids auth-prompt edge cases)
  rm -rf "$tmp"
  local base="${url%.git}"
  local ztmp="/tmp/${name}.zip"

  for br in main master; do
    if curl -fsSL -o "$ztmp" "${base}/archive/refs/heads/${br}.zip" >/dev/null 2>&1; then
      rm -rf "$tmp"
      unzip -q "$ztmp" -d /tmp
      local extracted="/tmp/$(basename "$base")-${br}"
      if [ -d "$extracted" ]; then
        mv "$extracted" "$dest"
        log "✅ Cloned (zip): $name"
        return 0
      fi
    fi
  done

  log "💥 Failed to fetch: $name ($url)"
  return 1
}

install_requirements_filtered() {
  # install_requirements_filtered REQ_FILE
  local req="$1"
  [ -f "$req" ] || return 0

  # Some nodes try to install opencv-python(-headless) which breaks ximgproc;
  # we always manage OpenCV ourselves (opencv-contrib-python).
  local tmp
  tmp="$(mktemp)"
  grep -vE '^(opencv-python|opencv-python-headless|opencv-contrib-python|opencv-contrib-python-headless)\b' "$req" > "$tmp" || true
  if [ -s "$tmp" ]; then
    python -m pip install -r "$tmp" >/dev/null
  fi
  rm -f "$tmp"
}

# -------------------------
# Start
# -------------------------
need_cmd git
need_cmd aria2c
need_cmd python3.12

log "🚀 Boot starting"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || true

mkdir -p "$WORKSPACE" "$CACHE_DIR" "$VENV_ROOT"

# Seed ComfyUI into /workspace once (so it persists on your volume)
if [ ! -d "$COMFY_DIR" ]; then
  log "🧱 Seeding ComfyUI into $COMFY_DIR"
  mkdir -p "$COMFY_DIR"
  rsync -a /opt/ComfyUI/ "$COMFY_DIR/"
  log "✅ ComfyUI seeded"
else
  log "✅ ComfyUI exists"
fi

# Persistent venv
if [ ! -d "$VENV_DIR" ]; then
  log "🐍 Creating venv: $VENV_DIR"
  python3.12 -m venv "$VENV_DIR"
  log "✅ venv created"
else
  log "✅ venv exists: $VENV_DIR"
fi

# Activate venv
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip wheel setuptools >/dev/null
log "✅ venv ready"

# -------------------------
# One-time bootstrap
# -------------------------
if [ ! -f "$SENTINEL" ]; then
  log "🧱 Full bootstrap starting (one-time per volume) 🔥"

  # 1) Torch (needed for sageattention build + ComfyUI)
  if ! python -c "import torch; print(torch.__version__)" >/dev/null 2>&1; then
    log "🔥 Installing PyTorch cu128"
    python -m pip install --upgrade \
      --index-url https://download.pytorch.org/whl/cu128 \
      torch==2.8.0+cu128 torchvision==0.23.0+cu128 torchaudio==2.8.0+cu128 >/dev/null
    log "✅ PyTorch installed"
  else
    log "✅ PyTorch already installed"
  fi

  # 2) ComfyUI deps
  if [ ! -f "$VENV_DIR/.reqs_comfyui_done" ]; then
    log "📦 Installing ComfyUI requirements"
    python -m pip install -r "$COMFY_DIR/requirements.txt" >/dev/null
    touch "$VENV_DIR/.reqs_comfyui_done"
    log "✅ ComfyUI requirements done"
  else
    log "✅ ComfyUI requirements already done"
  fi

  # 3) Fix OpenCV contrib (guidedFilter / ximgproc) + onnx + sageattention
  log "🧩 Installing critical extras (opencv-contrib, onnx, sageattention)"
  python -m pip uninstall -y opencv-python opencv-python-headless opencv-contrib-python-headless >/dev/null 2>&1 || true
  python -m pip install --upgrade opencv-contrib-python onnx >/dev/null

  # Triton + SageAttention (required by KJNodes PatchSageAttentionKJ)
  python -m pip install --upgrade triton sageattention >/dev/null

  # Verify: sageattention
  python - <<'PY'
from sageattention import sageattn
print("sageattention OK")
PY
  log "✅ sageattention import OK ✅"

  # Verify: OpenCV guidedFilter
  python - <<'PY'
import cv2
assert hasattr(cv2, "ximgproc"), "cv2.ximgproc missing"
assert hasattr(cv2.ximgproc, "guidedFilter"), "cv2.ximgproc.guidedFilter missing"
print("opencv ximgproc OK")
PY
  log "✅ OpenCV ximgproc/guidedFilter OK ✅"

  # 4) Custom nodes (clone only if missing)
  CUSTOM_NODES="$COMFY_DIR/custom_nodes"
  mkdir -p "$CUSTOM_NODES"
  log "🧩 Custom nodes setup (parallel clone: $CLONE_JOBS jobs) 🚄"

  # Essential nodes first (workflow-critical / commonly used)
  declare -a REPOS=(
    "ComfyUI-KJNodes|https://github.com/kijai/ComfyUI-KJNodes.git"
    "ComfyUI-WanVideoWrapper|https://github.com/kijai/ComfyUI-WanVideoWrapper.git"
    "ComfyUI-WanMoeKSampler|https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
    "ComfyUI-PainterI2V|https://github.com/welltop-cn/ComfyUI-PainterI2V.git"
    "ComfyUI-FBCNN|https://github.com/Miosp/ComfyUI-FBCNN.git"
  )

  # The rest (nice-to-have; won’t block startup if one fails)
  declare -a OPTIONAL_REPOS=(
    "ComfyUI-Impact-Pack|https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    "ComfyUI-VideoHelperSuite|https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    "rgthree-comfy|https://github.com/rgthree/rgthree-comfy.git"
    "was-node-suite-comfyui|https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "comfyui_controlnet_aux|https://github.com/Fannovel16/comfyui_controlnet_aux.git"
    "ComfyUI_LayerStyle|https://github.com/chflame163/ComfyUI_LayerStyle.git"
    "ComfyUI_LayerStyle_Advance|https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git"
    "ComfyLiterals|https://github.com/MNeMoNiCuZ/ComfyLiterals.git"
    "masquerade-nodes-comfyui|https://github.com/BadCafeCode/masquerade-nodes-comfyui.git"
    "ComfyUI-Easy-Use|https://github.com/yolain/ComfyUI-Easy-Use.git"
    "ComfyUI-TeaCache|https://github.com/kijai/ComfyUI-TeaCache.git"
    "ComfyUI_essentials|https://github.com/cubiq/ComfyUI_essentials.git"
    "cg-use-everywhere|https://github.com/chrisgoringe/cg-use-everywhere.git"
    "cg-image-picker|https://github.com/chrisgoringe/cg-image-picker.git"
  )

  fail=0

  # Clone essentials (fail if any missing)
  pids=()
  for entry in "${REPOS[@]}"; do
    IFS='|' read -r name url <<<"$entry"
    (
      clone_repo "$name" "$url" "$CUSTOM_NODES/$name"
    ) || exit 10
    ) &
    pids+=($!)
    if [ "${#pids[@]}" -ge "$CLONE_JOBS" ]; then
      wait -n || true
    fi
  done

  for pid in "${pids[@]}"; do
    wait "$pid" || fail=1
  done
  if [ "$fail" -ne 0 ]; then
    log "💥 A required node clone failed. (This is exactly what caused your 45-min repeat loops.)"
    exit 1
  fi

  # Clone optional (never block startup)
  pids=()
  for entry in "${OPTIONAL_REPOS[@]}"; do
    IFS='|' read -r name url <<<"$entry"
    (
      clone_repo "$name" "$url" "$CUSTOM_NODES/$name" || true
    ) &
    pids+=($!)
    if [ "${#pids[@]}" -ge "$CLONE_JOBS" ]; then
      wait -n || true
    fi
  done
  for pid in "${pids[@]}"; do wait "$pid" || true; done

  log "✅ Custom nodes complete 🎉"

  # 5) Install node requirements (filtered so they can’t break OpenCV)
  if [ ! -f "$VENV_DIR/.reqs_nodes_done" ]; then
    log "📦 Installing node requirements (filtered) 🧪"
    while IFS= read -r reqfile; do
      install_requirements_filtered "$reqfile"
    done < <(find "$CUSTOM_NODES" -maxdepth 3 -name requirements.txt 2>/dev/null || true)
    touch "$VENV_DIR/.reqs_nodes_done"
    log "✅ Node requirements done ✅"
  else
    log "✅ Node requirements already done"
  fi

  # 6) Fix ComfyLiterals web extension location (removes that “copy manually” warning)
  if [ -d "$CUSTOM_NODES/ComfyLiterals/web" ]; then
    mkdir -p "$COMFY_DIR/web/extensions"
    if [ ! -e "$COMFY_DIR/web/extensions/ComfyLiterals" ]; then
      ln -s "$CUSTOM_NODES/ComfyLiterals/web" "$COMFY_DIR/web/extensions/ComfyLiterals" || true
      log "✅ Linked ComfyLiterals web extension"
    fi
  fi

  # 7) Lightning LoRAs required by your workflow (fixes validation failure)
  LORA_DIR="$COMFY_DIR/models/loras"
  mkdir -p "$LORA_DIR"

  # These are what your workflow is asking for by name:
  # i2v_lightx2v_high_noise_model.safetensors
  # i2v_lightx2v_low_noise_model.safetensors
  #
  # We fetch from Lightx2v’s Wan2.2-Lightning repo and rename to match workflow.
  BASE="https://huggingface.co/lightx2v/Wan2.2-Lightning/resolve/main/Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1"
  aria_get "$BASE/high_noise_model.safetensors" "$LORA_DIR/i2v_lightx2v_high_noise_model.safetensors"
  aria_get "$BASE/low_noise_model.safetensors"  "$LORA_DIR/i2v_lightx2v_low_noise_model.safetensors"
  log "✅ Lightning LoRAs present ✅"

  # Only mark bootstrap done when EVERYTHING succeeded
  touch "$SENTINEL"
  log "🏁 Bootstrap finished — future reboots will be fast ⚡✅"
else
  log "⚡ Sentinel present — skipping bootstrap (fast start)"
fi

# -------------------------
# Start ComfyUI
# -------------------------
log "🎛️ Starting ComfyUI: python main.py $COMFYUI_ARGS"
cd "$COMFY_DIR"
exec python main.py $COMFYUI_ARGS
