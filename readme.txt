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
(echo g;echo w) | fdisk /dev/sda

# /dev/sda1 256M EFI
(echo n;echo ;echo ;echo 526335;echo t;echo 1;echo w) | fdisk /dev/sda

# /dev/sda2 512M Linux filesystem
(echo n;echo ;echo ;echo 1574911; echo w) | fdisk /dev/sda

# /dev/sda3 All Linux filesystem
(echo n;echo ;echo ;echo ; echo w) | fdisk /dev/sda

# Load encrypt modules 
modprobe dm-crypt
modprobe dm-mod

# Encrypt and open /dev/sda3  
cryptsetup luksFormat -v -s 512 -h sha512 /dev/sda3
cryptsetup open /dev/sda3 archlinux

# Formatting the partitions
mkfs.vfat -n "EFI System" /dev/sda1
mkfs.ext4 -L boot /dev/sda2
mkfs.ext4 -L root /dev/sda3

# Mount partitions and create folders
mount /dev/sda3 /mnt
mkdir /mnt/boot
mount /dev/sda2 /mnt/boot
mkdir /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

# Setup swap 
#count=<amount of your RAM>
dd if=/dev/zero of=/mnt/swap bs=1M count=16384 status=progress
chmod 0600 /mnt/swap
mkswap /mnt/swap
swapon /mnt/swap

# Install the system and some tools
pacstrap /mnt base linux linux-firmware base-devel efibootmgr iwd grub amd-ucode vim git wget 

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab

# Review the /mnt/etc/fstab
#rw,noatime

# Enter the new system
arch-chroot /mnt /bin/bash

# Create user
useradd -G wheel -m -d /home/user user
passwd user

# Ограничение на вход root
passwd --lock root

# set sudo privileges
vim /etc/sudoers
#uncomment %wheel ALL=(All) NOPASSWD: ALL

# Set the time zone and a system clock
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc --utc

# Generate and set default locale
vim /etc/locale.gen
# Uncomment en_US.UTF-8
locale-gen
echo LANG=en_US.utf8 > /etc/locale.conf

# Set the hostname
echo arch > /etc/hostname

# Set the host
vim /etc/hosts
#127.0.0.1   localhost arch
#::1         localhost arch

# Setup grub
# Edit /etc/default/grub
vim /etc/default/grub
#GRUB_CMDLINE_LINUX="cryptdevice=/dev/sda3:archlinux"

# Configure mkinitcpio
vim /etc/mkinitcpio.conf

# Add 'encrypt' to HOOKS before filesystems
HOOKS="base udev autodetect modconf block encrypt filesystems keyboard fsck"

# Regenerate initrd image
mkinitcpio -p linux

# Install grub and create configuration
grub-install --boot-directory=/boot --efi-directory=/boot/efi /dev/sda2
grub-mkconfig -o /boot/grub/grub.cfg
grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg

# Exit new system and go into the cd shell
exit

# Reboot into the new system, don't forget to remove the usb
reboot

# login user

# Install AUR helper - yay 
git clone https://aur.archlinux.org/yay.git ~/git/yay
cd ~/git/yay && makepkg -si

::TODO:: Update the installed packages. Finish configuration.
yay -Syu
-------------------------------------------------------------------------
# Optional: 
# Window manager
sudo pacman -S sway kitty ranger 
yay -S 

# AMD drivers
pacman -S mesa libva-mesa-driver mesa-vdpau xf86-video-amdgpu vulkan-radeon 

# Sound, bluetooth, vpn
sudo pacman -S alsa-utils 

# Office programs
sudo pacman -S libreoffice-still zathura 

# Utilities
sudo pacman -S keepass 

# System tools
sudo pacman -S bleachbit udiskie 
yay -S timeshift

# Multimedia
sudo pacman -S mpv

# Network
yay -S librewolf 

pacman -S 

# Virtualisation
pacman -S 

# Development
pacman -S code

---------------------------------------------
# Security (create systemd file)
sudo pacman -S ufw etckeeper rkhunter clamav clamtk
yay -S chkrootkit
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


snapper, htop, net-tools, wireless_tools,wpa_supplicant 
