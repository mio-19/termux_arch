#!/data/data/com.termux/files/usr/bin/bash
dir="$PWD/arch"

set -e

x11=false
sparkle=false
envs=''
if [ "$1" = "--x11" ]; then
  x11=true
  shift
fi
if [ "$1" = "--sparkle" ]; then
  sparkle=true
  shift
fi

if $x11 ;then
  export XDG_RUNTIME_DIR="${TMPDIR}/xdg"
  mkdir -p "$XDG_RUNTIME_DIR"
  chmod 777 "$XDG_RUNTIME_DIR"
  termux-x11 :1 &
  envs='DISPLAY=:1'
  sleep 5
  DISPLAY=:1 xhost + &
fi

chroot_add_mount() {
  if mount | grep "$2 " >/dev/null ;then return; fi
  sudo mount "$@"
}

chroot_setup() {
  chroot_add_mount "$1" "$1" --bind && # for bwrap/flatpak
  chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
  chroot_add_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
  chroot_add_mount run "$1/run" -t tmpfs -o nosuid,nodev &&
  chroot_add_mount tmp "$1/tmp" -t tmpfs -o nosuid,nodev &&
  chroot_add_mount /dev "$1/dev" --bind &&
  sudo mkdir -p "$1/dev/shm" &&
  chroot_add_mount shm "$1/dev/shm" -t tmpfs -o nosuid,nodev &&
  chroot_add_mount /dev/pts "$1/dev/pts" --bind
  if $x11 ;then
    sudo mkdir -p "$1/run/xdg"
    chroot_add_mount "$XDG_RUNTIME_DIR" "$1/run/xdg" --bind
    sudo mkdir -p "$1/tmp/.X11-unix"
    chroot_add_mount "$TMPDIR/.X11-unix" "$1/tmp/.X11-unix" --bind
    chmod 777 "$TMPDIR/.X11-unix"
    envs="$envs XDG_RUNTIME_DIR=/run/xdg"
  fi
  if $sparkle ;then
    sudo mkdir -p "$1/tmp/sparkle"
    chroot_add_mount /data/data/com.sion.sparkle/files "$1/tmp/sparkle" --bind
    sudo chmod 777 "$1/tmp/sparkle"
    sudo chmod 777 "$1/tmp/sparkle/wayland-0"
  fi
}

network_setup() {
  sudo rm -f "$1/etc/resolv.conf"
  sudo sh -c "echo nameserver 1.1.1.1 > '$1/etc/resolv.conf'"
  sudo sh -c "echo nameserver 8.8.8.8 >> '$1/etc/resolv.conf'"
}

network_setup "$dir"
chroot_setup "$dir"
unset PREFIX

#sudo mount -o remount,suid /data
sudo mount -o remount,suid "$dir"

exec sudo $envs TMPDIR=/tmp LD_PRELOAD= USER=root HOME=/root SHELL=/bin/bash chroot "$dir" "$@"
