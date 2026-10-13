#!/usr/bin/env bash
#
# 修复 GeForce MX150 (Pascal / GP108) 在 Arch 上"没有驱动"的问题
#
# 本机根因（三条证据）：
#   1) /usr/lib/modprobe.d/nvidia-utils.conf 里有 "blacklist nouveau"
#      —— 这是已装的 nvidia-utils(615) 带来的，nouveau 被禁了
#   2) NVIDIA 内核模块从来没装过（dkms / nvidia-dkms / nvidia-open-dkms 都没装）
#      => /sys/bus/pci/devices/0000:01:00.0/driver 不存在，nvidia-smi 直接报错
#   3) /usr/share/doc/nvidia/README 第 10555 行起明确写：
#      "Below are the legacy GPUs that are no longer supported in the unified driver."
#      "The 580.xx driver supports the following set of GPUs:"   ← 名单里含 MX150
#      （MX150 出现在 10814 / 10843 / 10845 行，下一节 470.xx 从 10871 行开始）
#      => 615 分支驱不动 MX150，必须走 580xx 遗留分支（archlinuxcn 提供）
#
# 用法：sudo bash setup-mx150.sh
#
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "请用 sudo 运行：sudo bash $0" >&2
    exit 1
fi

KVER="$(uname -r)"
echo "== 当前内核：$KVER =="
echo

echo "==> 1/5 先整体升级（Arch 上不要在部分升级状态下安装新包）"
pacman -Syu

echo
echo "==> 2/5 安装 DKMS 构建环境 + 580xx 遗留分支驱动"
echo "    提示：pacman 会提示 nvidia-580xx-utils 与已装 nvidia-utils(615) 冲突，按 y 替换"
pacman -S --needed dkms linux-headers nvidia-580xx-dkms nvidia-580xx-utils

echo
echo "==> 3/5 常用工具：prime-run(单程序调独显) / envycontrol(切模式) / nvtop(监控)"
pacman -S --needed nvidia-prime envycontrol nvtop

echo
echo "==> 4/5 重建 initramfs（你的 HOOKS 里有 kms，会自动带上 nvidia 模块）"
mkinitcpio -P

echo
echo "==> 5/5 自检"
echo "-- dkms 状态 --"
dkms status | grep -i nvidia || echo "（没看到 nvidia => 模块没编出来，见文末排查）"
echo "-- 内核模块文件 --"
find "/usr/lib/modules/$KVER" -name 'nvidia*.ko*' 2>/dev/null | head
echo "-- initramfs 里的 nvidia 条目数 --"
lsinitcpio /boot/initramfs-linux.img 2>/dev/null | grep -ci nvidia || true
echo "-- 当前屏蔽 nouveau 的配置（580xx 包自带，无需改动）--"
grep -rn blacklist /usr/lib/modprobe.d/ /etc/modprobe.d/ 2>/dev/null || true

cat <<'EOF'

==================== 下一步 ====================
重启，然后验证：

  nvidia-smi -L
     期望：GPU 0: NVIDIA GeForce MX150 (UUID: ...)
  lsmod | grep nvidia
     期望：nvidia_uvm nvidia_drm nvidia_modeset nvidia
  cat /sys/bus/pci/devices/0000:01:00.0/driver/module/version
     期望：580.178.04

日常用法：
  prime-run <程序>                 # 混合模式下，只让这个程序用独显
  sudo envycontrol -s integrated   # 完全关掉独显（最省电，需重启）
  sudo envycontrol -s hybrid       # 恢复默认混合模式
  sudo envycontrol -s nvidia       # 独显直连（性能最好、最费电）
  nvtop                            # 看占用/温度

如果 dkms status 里没有 nvidia（模块编译失败）：
  看日志：sudo dkms install -m nvidia -v 580.178.04 -k "$(uname -r)"
  实在编不过就退回开源驱动（不需要 NVIDIA 驱动）：
      sudo pacman -Rns nvidia-580xx-dkms nvidia-580xx-utils
      sudo rm -f /usr/lib/modprobe.d/nvidia-utils.conf
      sudo mkinitcpio -P && sudo reboot
  （nouveau 是内核自带开源驱动，Pascal 基本可用，但 3D 性能与功耗管理都不如
     580xx 专有驱动，也跑不了 CUDA）

回滚到当前状态：
  sudo pacman -Rns nvidia-580xx-dkms nvidia-580xx-utils envycontrol nvidia-prime
  sudo pacman -S nvidia-utils
  sudo mkinitcpio -P
================================================
EOF
