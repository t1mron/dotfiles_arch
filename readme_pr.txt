# Add ssh conection support
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl start sshd
passwd root

# Check internet connection
ping archlinux.org

# Sync time 
timedatectl set-ntp true 

# Wipe disk before install
head -c 3145728 /dev/urandom > /dev/sda; sync 
(echo g;echo w) | fdisk /dev/sda

# /dev/sda1 All Linux filesystem
(echo n;echo ;echo ;echo ; echo w) | fdisk /dev/sda

# Load encrypt module
modprobe dm-mod

# Encrypt and open /dev/sda1
cryptsetup -v --cipher serpent-xts-plain64 --key-size 512 --hash whirlpool --use-random --verify-passphrase luksFormat --type luks1 /dev/sda1 
cryptsetup open /dev/sda1 archlinux

# Create btrfs filesystem
mkfs -t btrfs --force -L archlinux /dev/mapper/archlinux

# ... and subvolumes
mount -t btrfs -o compress=lzo /dev/mapper/archlinux /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

# Unmount and remount with the corect partitions
umount /mnt

# Mount options
o=defaults,x-mount.mkdir
o_btrfs=$o,compress=lzo,ssd,noatime

# Remount the partitions
mount -o compress=lzo,subvol=@,$o_btrfs /dev/mapper/archlinux /mnt
mount -o compress=lzo,subvol=@home,$o_btrfs /dev/mapper/archlinux /mnt/home
mount -o compress=lzo,subvol=@snapshots,$o_btrfs /dev/mapper/archlinux /mnt/.snapshots

# Add nonsystemd package repo
echo [nonsystemd] >> /etc/pacman.conf 
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Verification of package signatures
pacman -Sy archlinux-keyring archlinuxarm-keyring parabola-keyring
pacman -U https://www.parabola.nu/packages/core/i686/archlinux32-keyring-transition/download/

# Install the system and some tools (OpenRC)
pacstrap /mnt linux-libre-lts base base-devel libelogind udev-init-scripts elogind btrfs-progs neovim git grub iwd

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Enter the new system
arch-chroot /mnt /bin/bash

# Create user
useradd -G wheel -m -d /home/user user
passwd user
useradd -G wheel -m -d /home/help help
passwd help

# Add sudo privileges
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Set the time zone and a system clock
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc --utc

# Set default locale
echo -e "en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8" >> /etc/locale.gen

# Update current locale
locale-gen

# Set system language
echo LANG=en_US.UTF-8 >> /etc/locale.conf

# Set keymap and font for console 
echo -e "KEYMAP=ru\nFONT=cyr-sun16" >> /etc/vconsole.conf

# Set the hostname
echo arch >> /etc/hostname

# Set the host
cat << EOF | tee -a /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    arch.localdomain arch
EOF

# Set systemd-networkd
cat << EOF | tee -a /etc/systemd/network/20-wired.network
[Match]
Name=enp1s0

[Network]
DHCP=yes
EOF

# Add multilib repo for pacman 
echo [multilib] >> /etc/pacman.conf 
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Setup grub
sed -i "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=1|" /etc/default/grub
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT='loglevel=3 quiet acpi_backlight=vendor'|" /etc/default/grub
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX='cryptdevice=/dev/nvme0n1p3:archlinux'|" /etc/default/grub

# Configure mkinitcpio
sed -i "s|^MODULES=.*|MODULES=(amdgpu)|" /etc/mkinitcpio.conf
sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)|" /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux

# Install grub and create configuration
grub-install --boot-directory=/boot --efi-directory=/boot/efi /dev/nvme0n1p2
grub-mkconfig -o /boot/grub/grub.cfg
grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg

# symlink resolv.conf
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Enable services at startup 
systemctl enable systemd-networkd
systemctl enable systemd-resolved

# Exit new system and go into the cd shell
exit

# Reboot into the new system, don't forget to remove the usb
reboot

sudo pacman -Syu

# Install AUR helper - yay
git clone https://aur.archlinux.org/yay.git /home/user/git/yay
cd /home/user/git/yay && makepkg -si

# Clone my repo
git clone https://github.com/t1mron/dotfiles_arch.git /home/user/git/dotfiles_arch
cd /home/user/git/dotfiles_arch && sudo cp -r etc / && cp /user/. /home/user/


-------------------------------------------------------------------------
::TODO:: Update the installed packages. Finish configuration.
yay 


# Optional: 

# AMD drivers
sudo pacman -S mesa lib32-mesa libva-mesa-driver mesa-vdpau xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader

# Window manager
sudo pacman -S i3-wm xorg-server xorg-xinit xorg-xev xorg-xprop xorg-xinput xorg-xsetroot xorg-xkill slock termite rofi nautilus xdg-user-dirs ttf-font-awesome arandr autorandr
yay -S polybar

xdg-user-dirs-update
sudo systemctl enable slock@user.service

# Laptop
sudo pacman -S libinput light tlp powertop libimobiledevice
sudo systemctl enable --now tlp
sudo powertop -c

# wi-fi, sound, bluetooth, vpn
sudo pacman -S iwd pulseaudio alsa-lib alsa-utils pavucontrol bluez bluez-utils blueman
yay -S iwgtk

sudo systemctl enable --now iwd
sudo modprobe btusb
sudo systemctl enable --now bluetooth
gsettings set org.blueman.plugins.powermanager auto-power-on false

  # Disable POP and BEEP sound
  sudo sh -c "echo 'blacklist snd_hda_codec_realtek' >> /etc/modprobe.d/disable_pop.conf"
  sudo sh -c "echo 'blacklist pcspkr' >> /etc/modprobe.d/nobeep.conf"

# Office programs
sudo pacman -S libreoffice-still zathura zathura-pdf-mupdf 

# Look and feel
sudo pacman -S neofetch lsd zsh zsh-completions
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Utilities
sudo pacman -S man-db flameshot redshift mpv sxiv gedit 
yay -S timeshift

# System tools
sudo pacman -S pacman-contrib bleachbit htop f2fs-tools dosfstools ntfs-3g gvfs gvfs-afc gvfs-gphoto2 udisks2 polkit-gnome 

# Network
sudo pacman -S wget reflector
sudo systemctl enable reflector

# Multimedia
sudo pacman -S firefox telegram-desktop obs-studio discord  
yay -S zoom

# Development
sudo pacman -S code

# Virtualisation 
sudo pacman -S virtualbox virtualbox-host-modules-arch 

----------------------------------------------------
wine qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libguestfs dmidecode ebtables iptables
sudo usermod -a -G libvirt user
sudo systemctl enable --now libvirtd.service
---------------------------------------------

# Security 
sudo pacman -S ufw doas
sudo ufw enable &&sudo ufw reload

#Disable root login over ssh
echo "PermitRootLogin no"| sudo tee -a /etc/ssh/sshd_config
echo "-:root:ALL except LOCAL" | sudo tee -a /etc/security/access.conf

# Disable root login
passwd --lock root
