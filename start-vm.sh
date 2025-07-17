#!/bin/bash
# 适用于 macOS 的 QEMU 启动脚本（兼容显卡配置）

VM_NAME="ubuntu-vm"
VM_DIR="/Users/feifei/.linux-vm"
DISK_PATH="${VM_DIR}/ubuntu-vm.qcow2"
ISO_PATH="${VM_DIR}/ubuntu.iso"
VM_RAM="4096"  # MB
VM_CPUS="2"

# 检查权限
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 sudo 运行：sudo $0"
    exit 1
fi

# 检查 QEMU 是否安装
if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "未找到 QEMU，请先安装：brew install qemu"
    exit 1
fi

# 首次启动（需要安装系统）
if [ -f "$ISO_PATH" ] && [ ! -f "${VM_DIR}/installed" ]; then
    echo "首次启动，加载安装镜像..."
    qemu-system-x86_64 \
        -name "$VM_NAME" \
        -machine q35,accel=hvf \
        -cpu host \
        -smp "$VM_CPUS" \
        -m "$VM_RAM" \
        -drive file="$DISK_PATH",format=qcow2,if=virtio \
        -drive file="$ISO_PATH",media=cdrom,if=virtio \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vga virtio \
        -display cocoa,show-cursor=on \
        -device virtio-keyboard \
        -device virtio-mouse

    # 标记为已安装（手动执行，避免误判）
    echo "请在系统安装完成后手动执行：touch ${VM_DIR}/installed"

# 后续启动（已安装系统）
else
    echo "启动已安装的系统..."
    qemu-system-x86_64 \
        -name "$VM_NAME" \
        -machine q35,accel=hvf \
        -cpu host \
        -smp "$VM_CPUS" \
        -m "$VM_RAM" \
        -drive file="$DISK_PATH",format=qcow2,if=virtio \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vga virtio \
        -display cocoa,show-cursor=on \
        -device virtio-keyboard \
        -device virtio-mouse
fi
