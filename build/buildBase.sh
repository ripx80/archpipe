#!/usr/bin/env sh
# Generate a minimal filesystem for archlinux

# must be a privileged container
#docker run -it --rm --privileged archlinux/base /bin/sh


set -e

HOSTNAME="node"

# setup system
pacman -Sy --noconfirm && pacman -S arch-install-scripts expect tar --noconfirm

export ROOTFS=$(mktemp -d ${TMPDIR:-/var/tmp}/rootfs-archlinux-XXXXXXXXXX)
chmod 755 $ROOTFS

# packages to ignore for space savings
PKGIGNORE=(
    dhcpcd
    iproute2
    jfsutils
    linux
    lvm2
    man-db
    man-pages
    mdadm
    nano
    netctl
    openresolv
    pciutils
    pcmciautils
    reiserfsprogs
    s-nail
    systemd-sysvcompat
    usbutils
    vi
    xfsprogs
)
IFS=','
PKGIGNORE="${PKGIGNORE[*]}"
unset IFS

expect <<EOF
	set send_slow {1 .1}
	proc send {ignore arg} {
		sleep .1
		exp_send -s -- \$arg
	}
    set timeout 1600
	spawn pacstrap -C /etc/pacman.conf -c -d -G -i $ROOTFS base haveged --ignore $PKGIGNORE
	expect {
		-exact "anyway? \[Y/n\] " { send -- "n\r"; exp_continue }
		-exact "(default=all): " { send -- "\r"; exp_continue }
		-exact "installation? \[Y/n\]" { send -- "y\r"; exp_continue }
	}
EOF

cp /etc/pacman.conf $ROOTFS/etc
cp /etc/pacman.d/mirrorlist $ROOTFS/etc/pacman.d/


cat <<EOF >$ROOTFS/etc/pacman.conf
[options]
HoldPkg     = pacman glibc
Architecture = auto
CheckSpace
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist

[multilib]
SigLevel = PackageRequired TrustedOnly
Include = /etc/pacman.d/mirrorlist
EOF

echo 'Server = https://ftp.halifax.rwth-aachen.de/archlinux/$repo/os/$arch'> /etc/pacman.d/mirrorlist


#arch-chroot $ROOTFS /bin/sh -c 'rm -r /usr/share/man/*'
arch-chroot $ROOTFS /bin/sh -c "haveged -w 1024 && pacman-key --init; pkill haveged; pacman -Rs --noconfirm haveged; pacman-key --populate archlinux" # pkill gpg-agent
arch-chroot $ROOTFS /bin/sh -c "test -e /etc/localtime && rm /etc/localtime; ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime"
echo 'en_US.UTF-8 UTF-8' > $ROOTFS/etc/locale.gen
arch-chroot $ROOTFS locale-gen

echo 'KEYMAP=de-latin1-nodeadkeys' > $ROOTFS/etc/vconsole.conf

#arch-chroot $ROOTFS /bin/sh -c 'echo "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist'

echo 'nameserver 9.9.9.9'>$ROOTFS/etc/resolv.conf

#clean up
arch-chroot $ROOTFS /bin/sh -c '/usr/bin/pacman -Sc --noconfirm && rm -r /var/cache/pacman'
#arch-chroot $ROOTFS /bin/sh -c '/usr/bin/pacman -Rnsc --noconfirm pam ca-certificates logrotate procps-ng which sed inetutils iputils diffutils gettext grep licenses psmisc sysfsutils;'
#arch-chroot $ROOTFS /bin/sh -c '/usr/bin/pacman -Sc --noconfirm && /usr/bin/pacman-optimize;cd /usr/share;rm -r zoneinfo zsh vim locale aclocal bash-completion doc emacs common-lisp gtk-doc info i18n iana-etc keyutils ca-certificates;rm -r /var/cache/pacman;'
echo $HOSTNAME> $ROOTFS/etc/hostname


cat <<"EOF" >$ROOTFS/etc/issue
#`````````` ___    ____    ____
#````______/```\__//```\__/____\
#``_/```\_/``:```````````//____ \
#`/|``````:``:``..``````/````````\   Host: 	    $HOSTNAME
#|`|`````::`````::``````\````````/   Admin: 	rip
#|`|`````:|`````||`````\`\______/    Contact:	hellme
#|`|`````||`````||``````|\``/``|
#`\|`````||`````||``````|```/`|`\
#``|`````||`````||``````|``/`/_\`\
#``|`___`||`___`||``````|`/``/````\
#```\_-_/``\_-_/`|`____`|/__/``````\	Be careful what you do...
#````````````````_\_--_/````\`````/
#```````````````/____```````````/	    we are watching you!
#``````````````/`````\`````````/
#``````````````\______\_______/
EOF

cat <<'EOF' >$ROOTFS/etc/bash.bashrc
[[ $- != *i* ]] && return

PS1=''
PS2='> '
PS3='> '
PS4='+ '

#gentoo like
case ${TERM} in
  xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
    ;;
  screen)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
    ;;
esac

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion

export EDITOR="nano"

alias paclear='pacman -Rns $(pacman -Qtdq)'

#Gentoo color style :-)
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
        && type -P dircolors >/dev/null \
        && match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true

if ${use_color} ; then
        # Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
        if type -P dircolors >/dev/null ; then
                if [[ -f ~/.dir_colors ]] ; then
                        eval $(dircolors -b ~/.dir_colors)
                elif [[ -f /etc/DIR_COLORS ]] ; then
                        eval $(dircolors -b /etc/DIR_COLORS)
                fi
        fi

        if [[ ${EUID} == 0 ]] ; then
                PS1+='\[\033[01;31m\]\h\[\033[01;34m\] \W \$\[\033[00m\] '
        else
                PS1+='\[\033[01;32m\]\u@\h\[\033[01;34m\] \w \$\[\033[00m\] '
        fi

        alias ls='ls --color=auto'
        alias grep='grep --colour=auto'
        alias egrep='egrep --colour=auto'
        alias fgrep='fgrep --colour=auto'
else
        if [[ ${EUID} == 0 ]] ; then
                # show root@ when we don't have colors
                PS1+='\u@\h \W \$ '
        else
                PS1+='\u@\h \w \$ '
        fi
fi

# Try to keep environment pollution down, EPA loves us.
unset use_color safe_term match_lhs sh
unset LESSOPEN
EOF

echo "arch-base-$(date +%Y-%m-%d)" >$ROOTFS/etc/arch-release

cat <<EOF >$ROOTFS/etc/modules-load.d/mods.conf
#acpi-cpufreq
#vboxdrv
#vboxvfs
#vboxvideo
#vboxguest
EOF

mkdir -p artefacts
tar --numeric-owner --xattrs --acls -C $ROOTFS -czf "/artefacts/archbase.tar.gz" .
chmod 766 /artefacts/archbase.tar.gz
# clear pacman db and other stuff

# add iptables stuff

