#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="endos"
iso_label="ENDOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="EndOS <https://github.com/USBKayble/EndOS>"
iso_application="EndOS Live - Arch Linux with Hyprland"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# Using zstd for much faster boot (slightly larger ISO)
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/home/liveuser"]="1000:1000:750"
  ["/home/liveuser/.zshrc"]="1000:1000:644"
  ["/home/liveuser/.zprofile"]="1000:1000:644"
  ["/home/liveuser/.zlogin"]="1000:1000:644"
  ["/home/liveuser/.automated_script.sh"]="1000:1000:755"
  ["/home/liveuser/dots-hyprland"]="1000:1000:755"
  ["/home/liveuser/.config"]="1000:1000:755"
  ["/home/liveuser/.local"]="1000:1000:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/post-install-dots.sh"]="0:0:755"
  ["/etc/greetd/config.toml"]="0:0:644"
  ["/etc/systemd/system/greetd.service"]="0:0:644"

  ["/etc/skel/dots-hyprland"]="0:0:755"
  ["/etc/skel/.config"]="0:0:755"
  ["/etc/skel/.local"]="0:0:755"
  ["/etc/sudoers.d/liveuser"]="0:0:440"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/etc/systemd/system/configure-liveuser-groups.service"]="0:0:644"
  ["/usr/local/bin/endos-debug"]="0:0:755"
  ["/usr/local/bin/qs"]="0:0:755"
)
