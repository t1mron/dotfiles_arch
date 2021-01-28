# Verify the boot mode 
ls /sys/firmware/efi/efivars
#If the command shows the directory without error, then the system is booted in UEFI mode. If the directory does not exist, the system may be booted in BIOS mode.

# Check internet connection
ping archlinux.org

# Sync time 
timedatectl set-ntp true 

# Choose the disk
fdisk -l

# Wipe disk before install
(echo g;echo w) | fdisk /dev/nvme0n1

# /dev/nvme0n1p1 256M EFI
(echo n;echo ;echo ;echo 526335;echo t;echo 1;echo w) | fdisk /dev/nvme0n1

# /dev/nvme0n1p2 512M Linux filesystem
(echo n;echo ;echo ;echo 1574911; echo w) | fdisk /dev/nvme0n1

# /dev/nvme0n1p3 All Linux filesystem
(echo n;echo ;echo ;echo ; echo w) | fdisk /dev/nvme0n1

# Load encrypt modules 
modprobe dm-crypt
modprobe dm-mod

# Encrypt and open /dev/nvme0n1p3  
cryptsetup luksFormat -v -s 512 -h sha512 /dev/nvme0n1p3
cryptsetup open /dev/nvme0n1p3 archlinux

# Formatting the partitions
mkfs.vfat -n "EFI System" /dev/nvme0n1p1
mkfs.ext4 -L boot /dev/nvme0n1p2
mkfs.ext4 -L root /dev/mapper/archlinux

# Mount partitions and create folders
mount /dev/mapper/archlinux /mnt
mkdir /mnt/boot
mount /dev/nvme0n1p2 /mnt/boot
mkdir /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

# Setup swap 
#count=<amount of your RAM>
dd if=/dev/zero of=/mnt/swap bs=1M count=16384 status=progress
chmod 0600 /mnt/swap
mkswap /mnt/swap
swapon /mnt/swap

# Install the system and some tools
pacstrap /mnt base linux linux-firmware base-devel efibootmgr grub amd-ucode vim git

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab

# Review the /mnt/etc/fstab
#rw,noatime

# Enter the new system
arch-chroot /mnt /bin/bash

# Create user
useradd -G wheel,video -m -d /home/user user
passwd user

# Disable root login
passwd --lock root

# set sudo privileges
echo "%wheel ALL=(All) NOPASSWD: ALL" >> /etc/sudoers

# Set the time zone and a system clock
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc --utc

# Set default locale
echo -e "en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8" >> /etc/locale.gen

# Update current locale
locale-gen

# Set system language
echo LANG="ru_RU.UTF-8" > /etc/locale.conf

# Set keymap and font for console 
echo KEYMAP=ru >> /etc/vconsole.conf
echo FONT=cyr-sun16 >> /etc/vconsole.conf

# Set the hostname
echo arch >> /etc/hostname

# Set the host
cat << EOF | tee -a /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    arch.localdomain arch
EOF

# set systemd-networkd
cat << EOF | tee -a /etc/systemd/network/20-wired.network
[Match]
Name=enp1s0

[Network]
DHCP=ipv4
EOF

# symlink resolv.conf
rm -rf /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Setup grub
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT='loglevel=3 quiet acpi_backlight=vendor'|" /etc/default/grub
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX='cryptdevice=/dev/nvme0n1p3:archlinux'|" /etc/default/grub

# Configure mkinitcpio
sed -i "s|^MODULES=.*|MODULES=(amdgpu)|" /etc/mkinitcpio.conf
sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)|" /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux

# Install grub and create configuration
grub-install --boot-directory=/boot --efi-directory=/boot/efi /dev/nvme0n1p2
grub-mkconfig -o /boot/grub/grub.cfg
grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg

# Enable services at startup 
systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved

# Install AUR helper - paru 
git clone https://aur.archlinux.org/paru.git ~/git/paru
cd ~/git/paru && makepkg -si

# Exit new system and go into the cd shell
exit

# Reboot into the new system, don't forget to remove the usb
reboot
-------------------------------------------------------------------------
::TODO:: Update the installed packages. Finish configuration.
paru 

# Optional: 
# Window manager
sudo pacman -S i3-wm xorg-server xorg-xinit xorg-xev termite rofi nautilus ttf-font-awesome arandr autorandr
paru -S polybar

# Network
paru  -S 
sudo pacman -S wget 

# AMD drivers
sudo pacman -S mesa libva-mesa-driver mesa-vdpau xf86-video-amdgpu vulkan-radeon 

# Laptop
sudo pacman -S xf86-input-synaptics light tlp
sudo systemctl enable --now tlp

# wi-fi, sound, bluetooth, vpn
sudo pacman -S iwd pulseaudio alsa-lib alsa-utils pavucontrol bluez bluez-utils blueberry
paru  -S iwgtk

sudo systemctl enable --now iwd
modprobe btusb
sudo systemctl enable --now bluetooth
  # Disable POP and BEEP sound
  sudo sed -i -e 's/load-module module-suspend-on-idle//g' /etc/pulse/default.pa
  echo "blacklist snd_hda_codec_realtek" | sudo tee -a /etc/modprobe.d/disable_pop.conf
  echo "blacklist pcspkr" | sudo tee -a /etc/modprobe.d/nobeep.conf

# Office programs
sudo pacman -S libreoffice-still zathura zathura-pdf-poppler zathura-ps

# Look and feel
paru -S lxappearance gruvbox-dark-gtk gruvbox-dark-icons-gtk

# Utilities
sudo pacman -S keepass man-db

# System tools
sudo pacman -S pacman-contrib neofetch bleachbit htop f2fs-tools dosfstools ntfs-3g gvfs 
paru -S timeshift-bin

# Multimedia
sudo pacman -S mpv telegram-desktop-bin
paru -S librewolf-bin spotify spotify-adblock-linux

# Virtualisation
sudo pacman -S 

# Development
sudo pacman -S code

---------------------------------------------
# Security (create systemd file)
sudo pacman -S ufw etckeeper rkhunter clamav clamtk
paru -S chkrootkit
#xss-lock

sudo ufw enable &&sudo ufw reload

sudo freshclam
#if error freshclam
sudo systemctl stop clamav-daemon.service
sudo rm /var/log/clamav/freshclam.log
sudo systemctl start clamav-daemon.service
sudo systemctl status clamav-daemon.service


vim /etc/systemd/system/rkhunter.service

__________________________________________
[Unit]
Description=rkhunter rootkit scan and malware detection

Documentation=man:rkhunter

[Service]
ExecStartPre=/usr/bin/rkhunter –update
ExecStartPre=/usr/bin/rkhunter –propupd
ExecStart=/usr/bin/rkhunter –check -sk
SuccessExitStatus=1 2
____________________________________
vim /etc/systemd/system/rkhunter.timer

[Unit]
Description=Run rkhunter daily

[Timer]
OnCalendar=*-*-* 04:20:00
Persistent=true

RemainAfterElapse=true

[Install]
WantedBy=timers.target
___________________________________________
ава
