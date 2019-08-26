#!/bin/bash

set -e

HOSTNAME='node1'
DISK='/dev/sda'
MOUNTPOINT='/mnt/sys'
SERVERADDR='10.0.50.107:8000'
ARCH='archbase.tar.gz'
mkdir -p $MOUNTPOINT

echo "[+] setting up disk"
sgdisk --clear \
  --new 1::+200M --typecode=1:ef00 --change-name=1:"efisystem" \
  --new 2::+2G --typecode=2:8200 --change-name=2:"swap" \
  --new 3::-0 --typecode=3:8300 --change-name=3:"root" \
  $DISK

mkfs.vfat ${DISK}1
mkswap ${DISK}2
mkfs.btrfs -f ${DISK}3

echo "[+] mount and prepare chroot"

mount ${DISK}3 ${MOUNTPOINT}
btrfs subvolume create ${MOUNTPOINT}/__active
btrfs subvolume create ${MOUNTPOINT}/__active/root
btrfs subvolume create ${MOUNTPOINT}/__active/var
btrfs subvolume create ${MOUNTPOINT}/__active/tmp
btrfs subvolume create ${MOUNTPOINT}/__active/home
btrfs subvolume create ${MOUNTPOINT}/__snapshot
umount ${MOUNTPOINT}

mount -o subvol=__active/root ${DISK}3 ${MOUNTPOINT}
mkdir -p ${MOUNTPOINT}/boot
mount ${DISK}1 ${MOUNTPOINT}/boot
for i in var home tmp;
  do
    mkdir -p ${MOUNTPOINT}/$i
    mount -o subvol=__active/$i ${DISK}3 ${MOUNTPOINT}/$i
done

echo "[+] get base system"
curl $SERVERADDR/$ARCH | tar -C ${MOUNTPOINT} -xpzf -
#tar -xpf /mnt/archbase.tar -C ${MOUNTPOINT}
#rm /mnt/archbase.tar

echo "[+] setting up system"
arch-chroot ${MOUNTPOINT} /bin/bash -c "timedatectl set-ntp true && hwclock --systohc"
genfstab -U ${MOUNTPOINT} >> ${MOUNTPOINT}/etc/fstab

arch-chroot ${MOUNTPOINT} /bin/bash -c "pacman -Syy && pacman -Su --noconfirm && pacman -S btrfs-progs refind-efi systemd systemd-sysvcompat net-tools netctl linux nano dhcpcd sudo --noconfirm"


cat <<EOF >$ROOTFS/etc/sudoers
Defaults  lecture="never"
root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
EOF

INF=$(ls /sys/class/net | sort -n | head -n1)
cp ${MOUNTPOINT}/etc/netctl/examples/ethernet-dhcp ${MOUNTPOINT}/etc/netctl/$INF
sed -i "s/eth0/$INF/g" ${MOUNTPOINT}/etc/netctl/$INF
arch-chroot ${MOUNTPOINT} /bin/bash -c "systemctl enable netctl && netctl enable $INF"

# iptables


echo "[+] setting up bootloader"
mkdir -p ${MOUNTPOINT}/etc/pacman.d/hooks

PART=$(blkid -o value -s PARTUUID ${DISK}3)
BOOTPARAM="root=PARTUUID=$PART rootflags=subvol=__active/root systemd.unit=multi-user.target rw add_efi_memmap"

cat << EOF >${MOUNTPOINT}/etc/pacman.d/hooks/refind.hook
[Trigger]
Operation=Upgrade
Type=Package
Target=refind-efi

[Action]
Description = Updating rEFInd on ESP
When=PostTransaction
Exec=/usr/bin/refind-install
EOF

arch-chroot ${MOUNTPOINT} /bin/bash -c "refind-install"


cat <<EOF >${MOUNTPOINT}/boot/EFI/refind/refind.conf

timeout 5
textonly
showtools reboot

menuentry "Arch Linux" {
    #icon     /EFI/refind/icons/os_arch.png
    volume   "Arch Linux"
    loader   /vmlinuz-linux
    initrd   /initramfs-linux.img
    options  "$BOOTPARAM"
}

#menuentry "Windows" {
#    loader \EFI\Microsoft\Boot\bootmgfw.efi
#    enabled
#}
EOF

cat <<EOF >${MOUNTPOINT}/boot/refind_linux.conf
"Boot with standard options"  "$BOOTPARAM"
EOF

cat <<EOF >${MOUNTPOINT}/boot/startup.nsh
vmlinuz-linux $BOOTPARAM initrd=/initramfs-linux.img
EOF

#this not working
echo "[+] create user"

arch-chroot ${MOUNTPOINT} /bin/bash -c "echo 'root:test'|chpasswd"
arch-chroot ${MOUNTPOINT} /bin/bash -c "useradd rip -m && usermod -a -G wheel,network rip; echo 'rip:test'|chpasswd"


for i in var home tmp boot;
  do
    umount ${MOUNTPOINT}/$i
done
umount ${MOUNTPOINT}

echo "[+] Installation finish successful"
echo "[+] you can reboot"
exit 0

# test -d /sys/firmware/efi/efivars && echo 'efi enabled'
#arch-chroot ${MOUNTPOINT} /bin/bash -c "mkinitcpio -p linux"

#efiinstall do this for us
#efibootmgr --create --disk ${DISK}3 --part 1 --loader /boot/EFI/refind/refind_x64.efi --label "Rips Boot Manager" --verbose
#python -c 'import crypt; print(crypt.crypt("test", crypt.mksalt(crypt.METHOD_SHA512)))'
#printf "mypassword2" | mkpasswd --stdin --method=sha-512 --salt "KdN5Re3X2X18"

#mkdir -p /boot/EFI/BOOT
#cp /usr/share/refind/refind_x64.efi esp/EFI/BOOT/
#mkdir esp/EFI/refind/drivers_x64
#cp /usr/share/refind/drivers_x64/drivername_x64.efi esp/EFI/refind/drivers_x64/


# set boot order
#efibootmgr -a -b 0003

#https://blog.heckel.xyz/2017/05/28/creating-a-bios-gpt-and-uefi-gpt-grub-bootable-linux-system/
# Create partition layout
#--new 1::+1M --typecode=1:ef02 --change-name=1:'BIOS boot partition' \

# add dnscrypt proxy
# add disk encryption


# Create sparse file (if we're not dealing with a block device)
#if [ ! -b "${DISK}" ]; then
#  truncate --size 30G $DISK
#fi


#truncate --size 30G test.img
#qemu-img convert -p -f raw -O qcow2 test.img disk1.img
#apt-get install ovmf -y --force-yes
#kvm --bios /usr/share/qemu/OVMF.fd -net none -drive format=raw,file=test.img -serial stdio -m 4G -cpu host -smp 2

#not needed if you use arch-chroot
#for d in dev sys; do mount --bind /$d ${MOUNTPOINT}/$d; done
#mount -t proc proc ${MOUNTPOINT}/proc
