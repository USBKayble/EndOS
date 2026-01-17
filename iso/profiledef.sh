#!/usr/bin/env bash
iso_name="EndOS"
iso_label="ENDOS_LIVE"
iso_publisher="EndOS <https://github.com/USBKayble/EndOS>"
iso_application="EndOS Live/Rescue CD"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito'
           'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.config"]="0:0:755"
  ["/root/.local"]="0:0:755"
  ["/root/.zlogin"]="0:0:755"

  ["/root/install_to_disk.sh"]="0:0:755"
)
