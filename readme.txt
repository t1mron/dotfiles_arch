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

# Install the system and some tools
pacstrap /mnt base linux linux-firmware base-devel efibootmgr grub amd-ucode vim git

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Enter the new system
arch-chroot /mnt /bin/bash

# Create user
useradd -G wheel -m -d /home/user user
passwd user

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

# Disable suspend button
echo HandleSuspendKey=ignore >> /etc/systemd/logind.conf

# Add multilib repo for pacman 
echo [multilib] >> /etc/pacman.conf 
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Setup grub
sed -i "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=1|" /etc/default/grub
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT='loglevel=3 quiet acpi_backlight=vendor'|" /etc/default/grub
sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX='cryptdevice=/dev/nvme0n1p3:archlinux'|" /etc/default/grub

# Configure mkinitcpio
sed -i "s|^MODULES=.*|MODULES=(amdgpu)|" /etc/mkinitcpio.conf
sed -i "s|^HOOKS=.*|HOOKS=(base udev autodetect modconf block keyboard encrypt fsck filesystems)|" /etc/mkinitcpio.conf

# Regenerate initrd image
mkinitcpio -p linux

# Install grub and create configuration
grub-install --boot-directory=/boot --efi-directory=/boot/efi /dev/nvme0n1p2
grub-mkconfig -o /boot/grub/grub.cfg
grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg

# Exit new system and go into the cd shell
exit

# Reboot into the new system, don't forget to remove the usb
reboot

# symlink resolv.conf
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Enable services at startup 
systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved

# Install AUR helper - paru 
git clone https://aur.archlinux.org/paru.git /home/user/git/paru
cd /home/user/git/paru && makepkg -si

# Clone my repo
git clone https://github.com/t1mron/dotfiles_arch.git /home/user/git/dotfiles_arch
cd /home/user/git/dotfiles_arch && sudo cp -r {etc,home} /


-------------------------------------------------------------------------
::TODO:: Update the installed packages. Finish configuration.
paru 


# Optional: 

# AMD drivers
sudo pacman -S mesa libva-mesa-driver mesa-vdpau xf86-video-amdgpu vulkan-radeon 

# Window manager
sudo pacman -S i3-wm xorg-server xorg-xinit xorg-xev xorg-xprop xorg-xkill slock termite rofi nautilus ttf-font-awesome arandr autorandr
paru -S polybar

# Laptop
sudo pacman -S xf86-input-synaptics light tlp powertop libimobiledevice
sudo systemctl enable --now tlp
sudo powertop -c

# wi-fi, sound, bluetooth, vpn
sudo pacman -S iwd pulseaudio alsa-lib alsa-utils pavucontrol bluez bluez-utils blueman
paru  -S iwgtk

sudo systemctl enable --now iwd
modprobe btusb
sudo systemctl enable --now bluetooth
gsettings set org.blueman.plugins.powermanager auto-power-on false

  # Disable POP and BEEP sound
  sudo sed -i -e 's/load-module module-suspend-on-idle//g' /etc/pulse/default.pa
  sudo sh -c "echo 'blacklist snd_hda_codec_realtek' >> /etc/modprobe.d/disable_pop.conf"
  sudo sh -c "echo 'blacklist pcspkr' >> /etc/modprobe.d/nobeep.conf"

# Office programs
sudo pacman -S libreoffice-still zathura zathura-pdf-poppler zathura-ps

# Look and feel
paru -S lxappearance gruvbox-dark-gtk gruvbox-dark-icons-gtk neofetch

# Utilities
sudo pacman -S keepass man-db flameshot qbittorrent redshift mpv sxiv

# System tools
sudo pacman -S pacman-contrib bleachbit htop f2fs-tools dosfstools ntfs-3g gvfs udisks2 polkit-gnome
paru -S timeshift-bin

# Network
paru  -S 
sudo pacman -S wget 

# Multimedia
sudo pacman -S firefox telegram-desktop obs-studio discord steam
paru -S librewolf-bin spotify polybar-spotify-module

systemctl --user enable spotify-listener

git clone https://github.com/abba23/spotify-adblock-linux.git ~/git/spotify-adblock-linux && cd ~/git/spotify-adblock-linux && wget -O cef.tar.bz2 https://cef-builds.spotifycdn.com/cef_binary_88.1.6%2Bg4fe33a1%2Bchromium-88.0.4324.96_linux64_minimal.tar.bz2 && tar -xf cef.tar.bz2 --wildcards '*/include' --strip-components=1 && make && sudo make install 

# Virtualisation
sudo pacman -S wine qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libguestfs dmidecode ebtables iptables
sudo systemctl enable --now libvirtd.service
sudo usermod -a -G libvirt user

# Development
sudo pacman -S code

---------------------------------------------

# Security (create systemd file)
sudo pacman -S ufw etckeeper rkhunter clamav clamtk doas
paru -S chkrootkit

sudo ufw enable &&sudo ufw reload

#Disable root login over ssh
echo "PermitRootLogin no"| sudo tee -a /etc/ssh/sshd_config

 
echo "-:root:ALL except LOCAL" | sudo tee -a /etc/security/access.conf



# Disable root login
passwd --lock root




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

