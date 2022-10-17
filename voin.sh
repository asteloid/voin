#!/usr/bin/env bash

set -xe

xchroot="chroot /mnt"

# disk
EFIDISK="/dev/sda1"
ROOTDISK="/dev/sda2"
HOMEDISK="/dev/sda3"

# user
#echo "User name:"
#read uservoid
#echo "Password:"
#read passvoid
uservoid="asteloid"
passvoid="ramentabetai"
hostnamevoid="ramenlab"
user_groups="wheel,sys,audio,input,video,storage,lp,network,users"
# enable zram
en_zram="true"

# voidconf
REPO="http://192.168.1.7:8080/cache/xbps/"
#"https://ftp.swin.edu.au/voidlinux"
ARCH="x86_64"
rm_sv=("agetty-tty3" "agetty-tty4" "agetty-tty5" "agetty-tty6")
en_sv=("NetworkManager" "acpid" "dbus" "elogind" "polkitd" "udevd" "uuidd" "pipewire-pulse" "pipewire" "iwd" "snooze-weekly" "thermald" "tlp" "earlyoom" "zramen")

# voidpkgs
sys_pkgs="grub-x86_64-efi base-system dialog cryptsetup lvm2 linux-headers mdadm dracut dracut-network dracut-uefi void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree"
xorg_pkgs="xorg-minimal xrdb xorg-fonts xorg-input-drivers xorg-video-drivers xsettingsd xrandr setxkbmap xsetroot xprop"
# intel graphics https://docs.voidlinux.org/config/graphical-session/graphics-drivers/intel.html
intel_pkgs="linux-firmware-intel xf86-video-intel intel-media-driver intel-video-accel libva-intel-driver libva-intel-driver-32bit mesa-vulkan-intel mesa-intel-dri mesa-vaapi mesa-vulkan-intel vulkan-loader intel-ucode sysfsutils"
userland_pkgs="opendoas vsv alacritty pcmanfm NetworkManager git jq curl inetutils wget ntp iwd \
    dbus-elogind dbus-elogind-libs dbus-elogind-x11 elogind polkit-gnome gnome-keyring polkit-elogind \
    exfat-utils gvfs-afc gvfs-mtp gvfs-smb ntfs-3g udisks2 udiskie \
    bsdtar p7zip unrar unzip xz zip zstd zutils \
    font-alias font-misc-misc font-util fontconfig librewolf-bin \
    pavucontrol ffmpeg ffmpegthumbnailer alsa-pipewire alsa-plugins-ffmpeg alsa-plugins-jack alsa-utils \
    flac gst-libav gst-plugins-ugly1 gstreamer-vaapi gstreamer1-pipewire lame libjack-pipewire \
    libspa-jack pipewire pulseaudio-utils v4l2loopback pkg-config mc xtools bc micro \
    acpi mpv redshift android-tools android-udev-rules earlyoom micro zramen snooze \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs xdg-user-dirs-gtk"
jainput_pkgs="fcitx5 fcitx5-configtool fcitx5-mozc fcitx5-gtk+3 fcitx5-qt5"
awewm_pkgs="lua53 awesome rofi"
kde_pkgs="plasma-desktop bluedevil breeze-gtk kde-gtk-config5 kdeplasma-addons5 \
    kscreen kwrited plasma-nm plasma-pa powerdevil xdg-desktop-portal-kde upower"
# ThinkPads from model year 2011 onwards - Therefore no external kernel modules are required with kernel 5.17 or newer and you do not need to proceed any further here.
# if you are running a kernel prior to linux5.17 (e.g. linux-lts) and want to use recalibration or your model is older, read: https://linrunner.de/tlp/installation/arch.html
# add tp_smapi-dkms acpi_call-dkms if you are running a kernel/linux-lts/linux5.16--
thinkpad_pkgs="lm_sensors tlp tlp-rdw thermald smartmontools intel-undervolt"

# Prepare disk
# root
yes | mkfs.ext4 -L voidlinux $ROOTDISK
mount $ROOTDISK /mnt
# home
#uncomment to reformat disk #yes | mkfs.ext4 -L voidlinux /dev/sda3###
mkdir -p /mnt/home
mount $HOMEDISK /mnt/home
# efi
#uncomment to reformat disk #yes | mkfs.vfat -n boot /dev/sda1###
yes | mkfs.vfat -n boot /dev/sda1
mkdir -p /mnt/boot/efi
mount $EFIDISK /mnt/boot/efi

# Copy the RSA keys
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# Install basesystem
XBPS_ARCH=$ARCH xbps-install -S -r /mnt -R "$REPO" $sys_pkgs --yes

# Mount the pseudo-filesystems needed for a chroot
mkdir -p /mnt/sys && mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys
mkdir -p /mnt/dev && mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev
mkdir -p /mnt/proc && mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc

# Copy the DNS configuration into the new root so that XBPS can still download new packages inside the chroot
cp /etc/resolv.conf /mnt/etc/

# Set hostname & locale
echo $hostnamevoid >/mnt/etc/hostname
echo 'LANG="en_US.UTF-8"' >/mnt/etc/locale.conf
sed -i '/^#en_US.UTF-8/s/.//' /mnt/etc/default/libc-locales

# Set fstab
uuid_uefi=$(blkid -s UUID -o value $EFIDISK)
uuid_root=$(blkid -s UUID -o value $ROOTDISK)
uuid_home=$(blkid -s UUID -o value $HOMEDISK)
echo -e "UUID=$uuid_root / ext4 nobarrier,data=writeback,noatime,nodiratime,errors=remount-ro 0 1" >> /mnt/etc/fstab
echo -e "UUID=$uuid_uefi /boot/efi vfat nofail,noatime,nodiratime 0 2" >> /mnt/etc/fstab
echo -e "UUID=$uuid_home /home ext4 nobarrier,data=writeback,noatime,nodiratime,errors=remount-ro 0 2" >> /mnt/etc/fstab
echo -e "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /mnt/etc/fstab
echo -e "tmpfs /var/log tmpfs defaults,noatime,mode=0755 0 0" >> /mnt/etc/fstab
echo -e "tmpfs /var/spool tmpfs defaults,noatime,mode=1777 0 0" >> /mnt/etc/fstab
echo -e "tmpfs /var/tmp tmpfs defaults,noatime,mode=1777 0 0" >> /mnt/etc/fstab

# Set localtime
$xchroot ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# Generate locale files
$xchroot xbps-reconfigure -f glibc-locales

# Create ignorepkg
cat << EOF > /mnt/etc/xbps.d/99-ignore.conf
ignorepkg=sudo
ignorepkg=wpa_supplicant
ignorepkg=btrfs-progs
ignorepkg=f2fs-tools
ignorepkg=hicolor-icon-theme
ignorepkg=ipw2100-firmware
ignorepkg=ipw2200-firmware
ignorepkg=linux-firmware-amd
ignorepkg=linux-firmware-broadcom
ignorepkg=mobile-broadband-provider-info
ignorepkg=nvi
ignorepkg=openssh
ignorepkg=rtkit
ignorepkg=void-artwork
ignorepkg=xbacklight
ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-video-ati
ignorepkg=xf86-video-fbdev
ignorepkg=xf86-video-nouveau
ignorepkg=xf86-video-vesa
ignorepkg=xf86-video-vmware
ignorepkg=zd1211-firmware
ignorepkg=ksystemstats
ignorepkg=oxygen
ignorepkg=plasma-systemmonitor
ignorepkg=plasma-thunderbolt
ignorepkg=plasma-workspace-wallpapers
EOF

# Allow users in the wheel group to use sudo
#sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL) ALL/" /mnt/etc/sudoers
# opendoas
cat << EOF >> /mnt/etc/doas.conf
permit persist keepenv root
permit persist keepenv :wheel
permit nopass $uservoid cmd xbps-install
permit nopass $uservoid cmd xbps-remove
permit nopass $uservoid cmd poweroff
permit nopass $uservoid cmd reboot
EOF

echo -e 'alias sudo="doas"' >> /mnt/etc/bash/bashrc

# install userpkgs
xbps-install -S -r /mnt -R "$REPO" xbps $xorg_pkgs $intel_pkgs $userland_pkgs $jainput_pkgs $awewm_pkgs $thinkpad_pkgs $kde_pkgs --yes

# set NetworkManager to use iwd as a backend
cat << EOF >> /mnt/etc/NetworkManager/NetworkManager.conf
[main]
plugins=keyfile
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

cat << EOF > /mnt/etc/iwd/main.conf
[General]
UseDefaultInterface=true
EOF

# The 10-wpa_supplicant hook, if enabled, automatically launches wpa_supplicant on wireless interfaces. It is started only if
#$xchroot ln -s /usr/libexec/dhcpcd-hooks/10-wpa_supplicant /usr/share/dhcpcd/hooks/10-wpa_supplicant

# Grub
$xchroot sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/c\GRUB_CMDLINE_LINUX_DEFAULT="loglevel=0 console=tty2 udev.log_level=0 vt.global_cursor_default=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable ipv6.disable=1"' /etc/default/grub
$xchroot grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=voidlinux --recheck
$xchroot grub-mkconfig -o /boot/grub/grub.cfg

#Disable services as selected above
for service in ${rm_sv[@]}; do
	if [[ -e /mnt/etc/runit/runsvdir/default/$service ]]; then
		$xchroot rm /etc/runit/runsvdir/default/$service
        $xchroot touch /etc/sv/$service/down
	fi
done

#Enable services as selected above
for service in ${en_sv[@]}; do
	if [[ ! -e /mnt/etc/runit/runsvdir/default/$service ]]; then
		$xchroot ln -s /etc/sv/$service /etc/runit/runsvdir/default/
	fi
done

$xchroot useradd -m -G $user_groups -s /bin/bash $uservoid

cat << EOF | chroot /mnt
echo "$passvoid\n$passvoid" | passwd -q root
echo "$passvoid\n$passvoid" | passwd -q $uservoid
EOF

$xchroot xbps-reconfigure -fa

# Tweaks
cat << EOF >> /mnt/etc/sysctl.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.min_free_kbytes = 131072
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
net.core.somaxconn = 1024
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.route.flush = 1
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.tcp_fastopen = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_frto = 2
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.optmem_max = 40960
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65536 8388608
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_forward = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv6.route.flush = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

cat << EOF >> /mnt/etc/tlp.conf
TLP_ENABLE=1
TLP_WARN_LEVEL=0
TLP_DEFAULT_MODE=AC
TLP_PERSISTENT_DEFAULT=0
DISK_IDLE_SECS_ON_AC=0
DISK_IDLE_SECS_ON_BAT=2
MAX_LOST_WORK_SECS_ON_AC=15
MAX_LOST_WORK_SECS_ON_BAT=60
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
SCHED_POWERSAVE_ON_AC=1
SCHED_POWERSAVE_ON_BAT=1
NMI_WATCHDOG=0
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power
DISK_DEVICES="sda"
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"
SATA_LINKPWR_ON_AC="med_power_with_dipm medium_power"
SATA_LINKPWR_ON_BAT="med_power_with_dipm min_power"
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
USB_AUTOSUSPEND=1
DEVICES_TO_DISABLE_ON_STARTUP="bluetooth nfc wwan"
DEVICES_TO_DISABLE_ON_BAT="bluetooth nfc wwan"
DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE="bluetooth nfc wwan"
START_CHARGE_THRESH_BAT0=69
STOP_CHARGE_THRESH_BAT0=86
START_CHARGE_THRESH_BAT1=69
STOP_CHARGE_THRESH_BAT1=86
DEVICES_TO_DISABLE_ON_LAN_CONNECT="wifi wwan"
DEVICES_TO_ENABLE_ON_LAN_DISCONNECT="wifi"
EOF

# Set up weekly fstrim
[[ -d /mnt/etc/cron.weekly ]] || mkdir -p /mnt/etc/cron.weekly/
cat << EOF > /mnt/etc/cron.weekly/fstrim
#!/bin/sh
fstrim /boot/efi
fstrim /
fstrim /home
EOF

$xchroot chmod +x /etc/cron.weekly/fstrim

# intel graphics
[[ -d /mnt/etc/X11/xorg.conf.d/ ]] || mkdir -p /mnt/etc/X11/xorg.conf.d/
cat << EOF > /mnt/etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
    Identifier    "Intel Graphics"
    Driver         "intel"
    Option        "AccelMethod"    "sna"
    Option        "TearFree"       "true"
    #Option        "DRI"            "3"
    #Option        "TripleBuffer"   "true"
EndSection
EOF

cat << EOF > /mnt/etc/X11/xorg.conf.d/90-monitor.conf
Section "Monitor"
    Identifier    "<default monitor>"
    DisplaySize   277 156    # In millimeters
EndSection
EOF

[[ -d /mnt/etc/sv/intel-undervolt/ ]] || mkdir -p /mnt/etc/sv/intel-undervolt/
cat << EOF > /mnt/etc/sv/intel-undervolt/run
#!/bin/sh
intel-undervolt apply >/dev/null 2>&1
exec chpst -b intel-undervolt pause
EOF

cat << EOF > /mnt/etc/intel-undervolt.conf
# Enable or Disable Triggers (elogind)
# Usage: enable [yes/no]

enable yes

# CPU Undervolting
# Usage: undervolt ${index} ${display_name} ${undervolt_value}
# Example: undervolt 2 'CPU Cache' -25.84

undervolt 0 'CPU' -153
undervolt 1 'GPU' -115
undervolt 2 'CPU Cache' -80
undervolt 3 'System Agent' 0
undervolt 4 'Analog I/O' 0

# Power Limits Alteration
# Usage: power ${domain} ${short_power_value} ${long_power_value}
# Power value: ${power}[/${time_window}][:enabled][:disabled]
# Domains: package
# Example: power package 45 35
# Example: power package 45/0.002 35/28
# Example: power package 45/0.002:disabled 35/28:enabled

# Critical Temperature Offset Alteration
# Usage: tjoffset ${temperature_offset}
# Example: tjoffset -20

# Energy Versus Performance Preference Switch
# Usage: hwphint ${mode} ${algorithm} ${load_hint} ${normal_hint}
# Hints: see energy_performance_available_preferences
# Modes: switch, force
# Load algorithm: load:${capture}:${threshold}
# Power algorithm: power[:${domain}:[gt/lt]:${value}[:[and/or]]...]
# Capture: single, multi
# Threshold: CPU usage threshold
# Domain: RAPL power domain, check with `intel-undervolt measure`
# Example: hwphint force load:single:0.8 performance balance_performance
# Example: hwphint switch power:core:gt:8 performance balance_performance

# Daemon Update Interval
# Usage: interval ${interval_in_milliseconds}

interval 5000

# Daemon Actions
# Usage: daemon action[:option...]
# Actions: undervolt, power, tjoffset
# Options: once

daemon undervolt:once
daemon power
daemon tjoffset
EOF

$xchroot chmod +x /etc/sv/intel-undervolt/run
$xchroot ln -s /etc/sv/intel-undervolt /etc/runit/runsvdir/default/

# fix font rendering
$xchroot mkdir -p /etc/fonts/conf.d/
$xchroot ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
$xchroot xbps-reconfigure -f fontconfig

unneed_pkgs="sudo wpa_supplicant btrfs-progs f2fs-tools hicolor-icon-theme ipw2100-firmware ipw2200-firmware linux-firmware-amd \
    linux-firmware-broadcom mobile-broadband-provider-info nvi openssh rtkit void-artwork xbacklight \
    xf86-video-amdgpu xf86-video-ati xf86-video-fbdev xf86-video-nouveau xf86-video-vesa xf86-video-vmware zd1211-firmware \
    ksystemstats oxygen plasma-systemmonitor plasma-thunderbolt plasma-workspace-wallpapers"
$xchroot xbps-remove -Ooy $unneed_pkgs

cat << EOF > /mnt/etc/default/earlyoom
OPTS="-m 96,92 -s 99,99 -p -r 5 --avoid '(^|/)(init|runit|runsv(dir)?|awesome|Xorg|ssh)$' --prefer '(^|/)(java|firefox|librewolf|chromium)$'"
EARLYOOM_ARGS="-m 96,92 -s 99,99 -p -r 5 --avoid '(^|/)(init|runit|runsv(dir)?|awesome|Xorg|ssh)$' --prefer '(^|/)(java|firefox|librewolf|chromium)$'"
EOF

if $en_zram
then

cat <<EOF >/mnt/etc/sv/zramen/conf
export ZRAM_COMP_ALGORITHM='lz4'
export ZRAM_PRIORITY=32767
export ZRAM_SIZE=30
export ZRAM_STREAMS=1
EOF

# increase value if zram=enable
sed -i 's#vm.swappiness = .*#vm.swappiness = 80#g' /mnt/etc/sysctl.conf
sed -i 's#vm.vfs_cache_pressure = .*#vm.vfs_cache_pressure = 300#g' /mnt/etc/sysctl.conf

fi

cat << EOF > /mnt/etc/skel/.xinitrc
#!/usr/bin/env bash
# dbus-launch
if which dbus-launch >/dev/null && test -z \$DBUS_SESSION_BUS_ADDRESS; then
    eval `dbus-launch --sh-syntax --exit-with-session`
fi

# fcitx5
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export INPUT_METHOD=fcitx
export SDL_IM_MODULE=fcitx

# make sure to load .xprofile if it exists,
# using it to set paths
[ -e ~/.xprofile ] && . ~/.xprofile

#xset +fp /usr/share/fonts/local
#xset fp rehash

fcitx5 &
/usr/bin/pipewire &
/usr/bin/pipewire-media-session &
/usr/bin/pipewire-pulse &

# start the window manager
session=${1:-kde}
#session=awesome
case $session in
    awesome|awesomewm )
        exec awesome;;
    kde )
        export DESKTOP_SESSION=plasma
        exec startplasma-x11;;
    xfce|xfce4 )
        exec startxfce4;;
    # No known session, try to run it as command
    * ) exec "${1}";;
esac
EOF

$xchroot chmod +x /etc/skel/.xinitrc

#chroot_actions(){
#    
#}

#export -f chroot_actions
#$xchroot /bin/bash -c "chroot_actions"

echo "Press any key to reboot."
read pause
umount -R /mnt
reboot
