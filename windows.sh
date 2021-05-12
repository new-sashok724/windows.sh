#!/bin/sh
# sashok724 was here
set -euo pipefail

# Too long to write options
cpucores=8
ramgig=20

cpufeatures=+topoext,+invtsc,host-cache-info=on,l3-cache=on
hvflags=hv-passthrough=on,hv-spinlocks=0x1fff,hv-vendor-id=oknvidia

audioflags=in.frequency=48000,out.frequency=48000
driveflags=file.aio=threads,discard=unmap,cache.direct=on

# Currently unneeded:
#-drive file=/usr/share/virtio/virtio-win.iso,media=cdrom \
#-blockdev driver=raw,file.driver=file,file.filename=".iso",$driveflags,read-only=on,node-name=cd-arch
#-device scsi-cd,drive=cd-arch,bus=scsi.0,id=scsi-cd-arch

#-device usb-audio,bus=xhci.0,port=1,audiodev=audiodev,id=usbaudio \
#-device e1000,bus=pcie.0,mac=10:56:f2:d7:6f:9b,netdev=netdev,id=net \

lgpath=/dev/shm/looking-glass-win
touch "$lgpath"
chmod 640 "$lgpath"
chown sashok724:sashok724 "$lgpath"

jemalloc.sh qemu-system-x86_64 -no-user-config -nodefaults \
    -name guest=qemuwin,debug-threads=on -msg timestamp=on \
    -accel kvm,kernel-irqchip=on -no-hpet \
    -cpu host,check,enforce,migratable=no,kvm=on,$cpufeatures,$hvflags \
    -smp $(($cpucores*2)),sockets=1,cores=$cpucores,threads=2 -mem-prealloc -m ${ramgig}G \
    -overcommit cpu-pm=on,mem-lock=on \
    \
    -machine q35,dump-guest-core=off,mem-merge=off,vmport=off,pflash0=ovmf-code,pflash1=ovmf-vars \
    -boot menu=on,strict=on,order=dc,splash-time=5000 -rtc base=utc,clock=host,driftfix=none \
    -monitor unix:"/run/windows/monitor.sock",server,nowait -vga none -display none -serial none -parallel none \
    -spice addr=127.0.0.1,port=5900,disable-ticketing=on \
    \
    -chardev spicevmc,name=vdagent,id=vdagent \
    -audiodev pa,server="/run/user/1000/pulse/native",$audioflags,id=audiodev \
    -blockdev driver=raw,file.driver=file,file.filename="/usr/share/ovmf/x64/OVMF_CODE.fd",$driveflags,read-only=on,node-name=ovmf-code \
    -blockdev driver=raw,file.driver=file,file.filename="/usr/local/etc/windows/ovmf_vars.fd",$driveflags,read-only=off,node-name=ovmf-vars \
    -blockdev driver=raw,file.driver=host_device,file.filename="/dev/mapper/windows",$driveflags,read-only=off,node-name=drive-system \
    -netdev tap,ifname=tapwin,script=no,downscript=no,vhost=on,id=netdev \
    -object memory-backend-file,mem-path="$lgpath",size=256M,share=on,id=ivshmem-mem \
    -object input-linux,evdev="/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse",id=imouse \
    -object input-linux,evdev="/dev/input/by-id/usb-LEOPOLD_LEO_98Keyboard-event-kbd",grab_all=on,repeat=on,id=ikbd \
    -object iothread,id=thread-scsi \
    -object rng-random,filename=/dev/urandom,id=urng \
    \
    -device pcie-root-port,bus=pcie.0,chassis=0,hotplug=false,id=vfio-gpu-port \
    -device pcie-root-port,bus=pcie.0,chassis=1,hotplug=false,id=vfio-usb-port \
    -device x3130-upstream,bus=vfio-usb-port,addr=00.0,id=vfio-usb-upstream \
    -device xio3130-downstream,bus=vfio-usb-upstream,addr=01.0,chassis=2,hotplug=false,id=vfio-usb-downstream1 \
    -device xio3130-downstream,bus=vfio-usb-upstream,addr=02.0,chassis=3,hotplug=false,id=vfio-usb-downstream2 \
    -device xio3130-downstream,bus=vfio-usb-upstream,addr=03.0,chassis=4,hotplug=false,id=vfio-usb-downstream3 \
    -device xio3130-downstream,bus=vfio-usb-upstream,addr=04.0,chassis=5,hotplug=false,id=vfio-usb-downstream4 \
    -device vfio-pci,bus=vfio-gpu-port,addr=00.0,host=14:00.0,multifunction=on,id=gpu \
    -device vfio-pci,bus=vfio-gpu-port,addr=00.1,host=14:00.1,id=gpu-audio \
    -device vfio-pci,bus=vfio-usb-downstream1,addr=00.0,host=07:00.0,id=usb1 \
    -device vfio-pci,bus=vfio-usb-downstream2,addr=00.0,host=08:00.0,id=usb2 \
    -device vfio-pci,bus=vfio-usb-downstream3,addr=00.0,host=09:00.0,id=usb3 \
    -device vfio-pci,bus=vfio-usb-downstream4,addr=00.0,host=0a:00.0,id=usb4 \
    -device virtio-scsi-pci,bus=pcie.0,num_queues=8,iothread=thread-scsi,ioeventfd=on,id=scsi \
    -device virtio-net-pci,bus=pcie.0,netdev=netdev,mac=10:56:f2:d7:6f:9b,mq=off,ioeventfd=on,mq=on,vectors=18,id=net \
    -device scsi-hd,drive=drive-system,bus=scsi.0,rotation_rate=1,id=scsi-drive-system \
    \
    -device virtio-mouse-pci,bus=pcie.0,id=mouse \
    -device virtio-keyboard-pci,bus=pcie.0,id=kbd \
    -device virtio-balloon,bus=pcie.0,id=balloon \
    -device virtio-rng-pci,bus=pcie.0,rng=urng,id=rng \
    -device virtio-serial-pci,bus=pcie.0,id=serial \
    -device ivshmem-plain,bus=pcie.0,memdev=ivshmem-mem,id=ivshmem \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0,id=serial-spice \
    -device intel-hda,bus=pcie.0,msi=on,id=hda \
    -device hda-duplex,audiodev=audiodev,id=hdad \
    \
    -device qemu-xhci,bus=pcie.0,p2=15,p3=15,id=xhci \
    -device usb-host,bus=xhci.0,port=2,vendorid=0x046d,productid=0xc08c,id=usbmouse \
    -device usb-host,bus=xhci.0,port=3,vendorid=0x046d,productid=0xc33f,id=usbkbd
