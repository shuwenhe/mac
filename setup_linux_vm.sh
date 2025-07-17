#!/usr/bin/env bash
# setup_linux_vm.sh - 在 macOS 上安装 Linux VM 的准备脚本

set -euo pipefail # 严格模式：遇到错误立即退出，未设置变量即退出，管道中任何命令失败即退出

# 函数：打印步骤信息
step() { echo -e "\n\e[36m[STEP]\e[0m $*"; }
# 函数：打印成功信息
success() { echo -e "\e[32m[SUCCESS]\e[0m $*"; }
# 函数：打印警告信息
warn() { echo -e "\e[33m[WARN]\e[0m $*"; }
# 函数：打印错误信息
error() { echo -e "\e[31m[ERROR]\e[0m $*"; exit 1; }

# --- 1. 检查并安装 Homebrew ---
step "1. 检查并安装 Homebrew (macOS 包管理器)"
if ! command -v brew &> /dev/null; then
  warn "Homebrew 未安装。正在安装 Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # 根据 Homebrew 安装提示，可能需要将 brew 添加到 PATH
  # 自动检测并添加 Homebrew 到 PATH
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  success "Homebrew 安装完成。"
else
  success "Homebrew 已安装。"
  brew update # 更新 Homebrew
fi

# --- 2. 安装 UTM 虚拟机管理程序 ---
step "2. 安装 UTM 虚拟机管理程序"
if ! brew list --cask | grep -q "utm"; then
  brew install --cask utm
  success "UTM 安装完成。"
else
  success "UTM 已安装。"
fi

# --- 3. 下载 Ubuntu Server ISO 镜像 ---
step "3. 下载 Ubuntu Server ISO 镜像"
# Ubuntu Server 22.04 LTS (长期支持版) 是一个稳定且常用的选择。
# 对于 Apple Silicon (ARM64) Mac，下载 arm64 版本。
# 对于 Intel (x86_64) Mac，下载 amd64 版本。

UBUNTU_ISO_DIR="${HOME}/Downloads/VM_ISOs"
mkdir -p "$UBUNTU_ISO_DIR"

if [[ "$(uname -m)" == "arm64" ]]; then
  UBUNTU_ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.4-live-server-arm66.iso" # ARM64 版本
  UBUNTU_ISO_FILENAME="ubuntu-22.04.4-live-server-arm64.iso"
  warn "检测到 Apple Silicon (ARM64) Mac，将下载 ARM64 版本的 Ubuntu Server。"
else
  UBUNTU_ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.4-live-server-amd64.iso" # AMD64 (Intel) 版本
  UBTU_ISO_FILENAME="ubuntu-22.04.4-live-server-amd64.iso"
  warn "检测到 Intel (x86_64) Mac，将下载 AMD64 版本的 Ubuntu Server。"
fi

UBUNTU_ISO_PATH="${UBUNTU_ISO_DIR}/${UBUNTU_ISO_FILENAME}"

if [[ -f "$UBUNTU_ISO_PATH" ]]; then
  success "Ubuntu Server ISO 镜像已存在：$UBUNTU_ISO_PATH"
else
  echo "正在从 $UBUNTU_ISO_URL 下载 $UBUNTU_ISO_FILENAME..."
  curl -L -o "$UBUNTU_ISO_PATH" "$UBUNTU_ISO_URL" || error "ISO 镜像下载失败。"
  success "Ubuntu Server ISO 镜像下载完成：$UBUNTU_ISO_PATH"
fi

success "准备工作完成！请继续执行第 2 步：在 UTM 中创建虚拟机。"
echo "您可以在应用程序文件夹中找到 UTM，ISO 镜像在：$UBUNTU_ISO_PATH"
