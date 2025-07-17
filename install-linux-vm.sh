#!/bin/bash
# install-linux-vm.sh - 在 macOS 上用 QEMU 安装 Ubuntu Linux 虚拟机（Apple Silicon）

set -euo pipefail

# ========== 配置项 ==========
UBUNTU_VERSION="22.04"
ARCH="arm64"  # Apple Silicon 使用 arm64，Intel Mac 可改为 amd64
IMAGE="ubuntu-${UBUNTU_VERSION}-server-cloudimg-${ARCH}.img"
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/releases/${UBUNTU_VERSION}/release/${IMAGE}"
DISK="ubuntu-disk.qcow2"
ISO="cloud-init.iso"
VM_NAME="ubuntu-vm"
DISK_SIZE="20G"
MEM="4096"     # 内存（MB）
CPUS="2"       # CPU 核数
SSH_PORT=2222  # 转发到主机的 SSH 端口

# ========== 步骤 1：下载 Ubuntu 镜像 ==========
echo "🚀 下载 Ubuntu Cloud Image (${UBUNTU_VERSION})"
if [ ! -f "$IMAGE" ]; then
  curl -LO "$CLOUD_IMG_URL"
fi

# ========== 步骤 2：创建磁盘 ==========
echo "💽 创建虚拟机磁盘镜像：$DISK"
qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"

# ========== 步骤 3：生成 cloud-init 配置 ==========
echo "🧾 生成 cloud-init 文件"
mkdir -p cloud-init

# user-data
cat > cloud-init/user-data <<EOF
#cloud-config
hostname: ${VM_NAME}
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: 'ubuntu'
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)

runcmd:
  - echo "Welcome to Ubuntu VM" > /etc/motd
EOF

# meta-data
cat > cloud-init/meta-data <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

# ISO 镜像
echo "📦 打包 cloud-init ISO"
hdiutil makehybrid -o "$ISO" -hfs -joliet -iso -default-volume-name cidata cloud-init/

# ========== 步骤 4：启动虚拟机 ==========
echo "🔧 启动 Ubuntu 虚拟机..."
qemu-system-aarch64 \
  -machine virt,accel=hvf \
  -cpu cortex-a72 \
  -smp "$CPUS" \
  -m "$MEM" \
  -nographic \
  -drive if=virtio,file="$DISK" \
  -drive if=virtio,file="$IMAGE",format=raw,readonly=on \
  -drive if=virtio,file="$ISO",format=raw \
  -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
  -device virtio-net-device,netdev=net0

# ========== 提示 ==========
echo ""
echo "✅ 启动完成！你可以使用如下命令 SSH 登录虚拟机："
echo "   ssh ubuntu@localhost -p ${SSH_PORT}"
echo "   默认密码：ubuntu（如果未配置公钥登录）"

