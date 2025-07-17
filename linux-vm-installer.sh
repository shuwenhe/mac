#!/bin/bash
# linux-vm-installer.sh — 在 macOS 上一键安装 Linux 虚拟机

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 常量定义
VM_NAME="ubuntu-vm"
VM_DISK_SIZE="20G"
VM_RAM="4096"
VM_CPUS="2"
ISO_URL="https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso"
ISO_CHECKSUM="sha256:b30c8f4d58e257a079a7e923c71bf7d086d9a33c3e1c32e359a63d0c1a244"
VM_DIR="${HOME}/.linux-vm"
ISO_PATH="${VM_DIR}/ubuntu.iso"
DISK_PATH="${VM_DIR}/${VM_NAME}.qcow2"

# 检查是否有sudo权限
check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌ 此脚本需要sudo权限才能运行。请使用sudo执行此脚本。${NC}"
        exit 1
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 步骤显示函数
step() {
    echo -e "${BLUE}[步骤]${NC} $1"
}

# 错误处理函数
error() {
    echo -e "${RED}❌ 错误: $1${NC}"
    exit 1
}

# 成功提示函数
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 下载ISO文件
download_iso() {
    step "下载Ubuntu安装镜像..."
    mkdir -p "$VM_DIR"
    
    if [ -f "$ISO_PATH" ]; then
        echo -e "${YELLOW}⚠️ 镜像文件已存在，跳过下载${NC}"
        # 验证校验和
        if command_exists shasum; then
            CHECKSUM=$(shasum -a 256 "$ISO_PATH" | awk '{print $1}')
            if [ "$CHECKSUM" != "${ISO_CHECKSUM#sha256:}" ]; then
                echo -e "${YELLOW}⚠️ 校验和不匹配，重新下载${NC}"
                rm "$ISO_PATH"
                curl -o "$ISO_PATH" "$ISO_URL"
            fi
        else
            echo -e "${YELLOW}⚠️ 无法验证校验和${NC}"
        fi
    else
        curl -o "$ISO_PATH" "$ISO_URL"
    fi
    
    success "镜像下载完成"
}

# 安装依赖
install_dependencies() {
    step "安装必要的依赖..."
    
    # 安装Homebrew（如果未安装）
    if ! command_exists brew; then
        echo -e "${YELLOW}🍺 安装Homebrew${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # 安装QEMU和Virt-manager
    brew install qemu virt-manager
    
    # 安装Virt-viewer（用于图形界面访问）
    brew install virt-viewer
    
    success "依赖安装完成"
}

# 创建虚拟机磁盘
create_disk() {
    step "创建虚拟机磁盘..."
    
    if [ -f "$DISK_PATH" ]; then
        read -p "磁盘文件已存在，是否删除并重新创建? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm "$DISK_PATH"
        else
            echo -e "${YELLOW}⚠️ 使用现有磁盘文件${NC}"
            return
        fi
    fi
    
    qemu-img create -f qcow2 "$DISK_PATH" "$VM_DISK_SIZE"
    success "磁盘创建完成: $DISK_PATH ($VM_DISK_SIZE)"
}

# 创建启动脚本
create_start_script() {
    step "创建虚拟机启动脚本..."
    
    START_SCRIPT="${VM_DIR}/start-vm.sh"
    
    cat > "$START_SCRIPT" <<EOF
#!/bin/bash
# 启动Ubuntu虚拟机

# 检查是否有足够的权限
if [ "\$(id -u)" -ne 0 ]; then
    echo "请使用sudo运行此脚本"
    exit 1
fi

# 检查依赖
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "未找到QEMU，请先安装QEMU"
    exit 1
fi

# 启动虚拟机
qemu-system-x86_64 \\
  -name "$VM_NAME" \\
  -machine q35,accel=hvf \\
  -cpu host \\
  -smp "$VM_CPUS" \\
  -m "$VM_RAM" \\
  -device virtio-vga,virgl=on \\
  -display default,show-cursor=on \\
  -device virtio-keyboard-pci \\
  -device virtio-mouse-pci \\
  -drive file="$DISK_PATH",format=qcow2,if=virtio \\
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \\
  -device virtio-net-pci,netdev=net0 \\
  -usb \\
  -device usb-tablet \\
  -vga qxl \\
  "\$@"
EOF
    
    chmod +x "$START_SCRIPT"
    success "启动脚本已创建: $START_SCRIPT"
    echo -e "${YELLOW}提示: 您可以使用以下命令启动虚拟机:${NC}"
    echo -e "${YELLOW}      sudo $START_SCRIPT${NC}"
}

# 主函数
main() {
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}        Linux虚拟机安装工具 (macOS)        ${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo
    
    check_sudo
    install_dependencies
    download_iso
    create_disk
    create_start_script
    
    echo
    echo -e "${GREEN}🎉 虚拟机环境已准备就绪!${NC}"
    echo -e "${YELLOW}下一步:${NC}"
    echo "  1. 使用以下命令启动虚拟机:"
    echo "     sudo ${VM_DIR}/start-vm.sh"
    echo "  2. 首次启动将进入Ubuntu安装界面"
    echo "  3. 安装完成后重启虚拟机"
    echo "  4. 通过Virt-manager管理虚拟机 (brew install virt-manager)"
    echo
    echo -e "${GREEN}提示: 虚拟机的SSH端口已映射到主机的2222端口${NC}"
    echo -e "${GREEN}     安装完成后可以使用: ssh -p 2222 user@localhost${NC}"
}

main "$@"
