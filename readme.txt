# Verify the boot mode 
ls /sys/firmware/efi/efivars
#If the command shows the directory without error, then the system is booted in UEFI mode. If the directory does not exist, the system may be booted in BIOS mode.

# Check internet connection
ping archlinux.org

# Sync time 
timedatectl set-ntp true 

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

# Setup zram

# Install the system and some tools
pacstrap /mnt base linux-lts linux-firmware base-devel efibootmgr grub amd-ucode neovim git wget

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Enter the new system
arch-chroot /mnt /bin/bash

# Create user
useradd -G wheel,rfkill -m -d /home/user user
passwd user
useradd -G wheel -m -d /home/help help
passwd help

# Add sudo privileges
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

echo "user arch = (root) NOPASSWD: /sbin/ip" >> /etc/sudoers
echo "user arch = (root) NOPASSWD: /sbin/light" >> /etc/sudoers

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
echo "[multilib]" >> /etc/pacman.conf 
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Setup grub
sed -i "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=1|" /etc/default/grub
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT='loglevel=3 quiet acpi_backlight=vendor'|" /etc/default/grub
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX='cryptdevice=/dev/nvme0n1p3:archlinux'|" /etc/default/grub

# Configure mkinitcpio
sed -i "s|^MODULES=.*|MODULES=(amdgpu)|" /etc/mkinitcpio.conf
sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)|" /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux-lts

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
sudo pacman -S bspwm sxhkd xorg-server xorg-xinit xorg-xev xorg-xprop xorg-xinput xorg-xsetroot xorg-xkill slock ranger kitty rofi ttf-font-awesome powerline-fonts arandr autorandr
yay -S polybar

sudo systemctl enable slock@user.service

# Laptop
sudo pacman -S libinput light tlp powertop libimobiledevice
sudo systemctl enable --now tlp
sudo powertop -c

# wi-fi, sound, bluetooth, vpn
sudo pacman -S iwd wireless_tools bc pulseaudio pulseaudio-alsa pulseaudio-bluetooth bluez bluez-utils pavucontrol blueberry

sudo systemctl enable --now iwd
sudo systemctl enable --now bluetooth
#sudo modprobe btusb

  # Disable POP and BEEP sound
  sudo sh -c "echo 'blacklist snd_hda_codec_realtek' >> /etc/modprobe.d/disable_pop.conf"
  sudo sh -c "echo 'blacklist pcspkr' >> /etc/modprobe.d/nobeep.conf"

# Office programs
sudo pacman -S libreoffice-still zathura zathura-pdf-mupdf

# Neovim plugins
# vim-plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Look and feel
sudo pacman -S neofetch lsd zsh zsh-completions
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# Utilities
sudo pacman -S man-db flameshot redshift mpv sxiv w3m
yay -S timeshift

# System tools
sudo pacman -S pacman-contrib htop f2fs-tools dosfstools ntfs-3g gvfs gvfs-afc gvfs-gphoto2 udisks2 polkit-gnome 

# Network
sudo pacman -S reflector
sudo systemctl enable reflector

# Multimedia
sudo pacman -S firefox telegram-desktop obs-studio discord

# Virtualisation 
sudo pacman -S 

----------------------------------------------------
wine qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libguestfs dmidecode ebtables iptables
sudo usermod -a -G libvirt user
sudo systemctl enable --now libvirtd.service
---------------------------------------------

# Security 
sudo pacman -S ufw 
sudo ufw enable 

#Disable root login over ssh
echo "PermitRootLogin no"| sudo tee -a /etc/ssh/sshd_config
echo "-:root:ALL except LOCAL" | sudo tee -a /etc/security/access.conf

# Disable root login
passwd --lock root
