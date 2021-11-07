#!/bin/bash
# sashok724 was here
set -euo pipefail

if [ $# -lt 2 ]; then
    echo 'Usage: <cpucores> <ramsize> [extra]'
    exit 1
fi

# Too long to write options
readonly cpucores="$1"
readonly ramsize="$2"

readonly cpufeatures=+topoext,+invtsc,host-cache-info=on,l3-cache=on
readonly hvflags=hv-passthrough=on,hv-spinlocks=0x1fff,hv-vendor-id=oknvidia

readonly audioflags=in.frequency=48000,out.frequency=48000
readonly driveflags_=file.aio=io_uring,discard=unmap,detect-zeroes=unmap
readonly driveflags_ro=$driveflags_,read-only=on,cache.direct=off
readonly driveflags_rw=$driveflags_,read-only=off
readonly driveflags_rwd=$driveflags_rw,cache.direct=on
readonly driveflags_rww=$driveflags_rw,cache.direct=off
readonly scsiflags4k=physical_block_size=4096,logical_block_size=4096

# Currently unneeded: (kvmflags are taken from kvm_default_props (qemu sources))
#readonly kvmflags=kvm=off,+kvmclock,+kvm-nopiodelay,+kvm-asyncpf,+kvm-steal-time,+kvm-pv-eoi,+kvmclock-stable-bit,+x2apic,-acpi,-monitor
#readonly hvflags=$hvflags,hv-vendor-id=fucknvidia

#-object input-linux,evdev="/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse",id=imouse \
#-object input-linux,evdev="/dev/input/by-id/usb-LEOPOLD_LEO_98Keyboard-event-kbd",grab_all=on,repeat=on,id=ikbd \

#-device scsi-cd,drive=cd-arch,bus=scsi.0,id=scsi-cd-arch \
#-device usb-audio,bus=xhci.0,port=1,audiodev=audiodev,id=usb-audio \
#-device e1000,bus=pcie.0,mac=10:56:f2:d7:6f:9b,netdev=netdev,id=net \

chown root:users /dev/kvmfr0
chmod 0660 /dev/kvmfr0
jemalloc.sh qemu-system-x86_64 -no-user-config -nodefaults \
    -name guest=qemuwin,debug-threads=on -msg timestamp=on \
    -accel kvm,kernel-irqchip=on -no-hpet \
    -cpu host,check,enforce,migratable=no,kvm=on,$cpufeatures,$hvflags \
    -smp $(($cpucores*2)),sockets=1,cores=$cpucores,threads=2 -mem-prealloc -m ${ramsize} \
    -global kvm-pit.lost_tick_policy=delay -global ICH9-LPC.disable_s3=1 \
    -overcommit cpu-pm=on,mem-lock=on \
    \
    -machine q35,dump-guest-core=off,mem-merge=off,vmport=off,pflash0=ovmf-code,pflash1=ovmf-vars \
    -boot menu=on,strict=on,order=dc,splash="/usr/local/etc/windows/splash.bmp",splash-time=30000 -rtc base=utc,clock=host,driftfix=slew \
    -monitor unix:"/run/windows/monitor.sock",server,nowait -qmp unix:"/run/windows/qmp.sock",server,nowait \
    -spice addr=127.0.0.1,port=5900,disable-ticketing=on,seamless-migration=off \
    -vga none -display none -serial none -parallel none \
    \
    -object iothread,id=thread-scsi \
    -object rng-random,filename=/dev/urandom,id=urng \
    -object memory-backend-file,mem-path="/dev/kvmfr0",size=128M,share=on,id=ivshmem-mem \
    -chardev socket,path="/run/windows/qga.sock",server=on,wait=off,name=qga,id=qga \
    -chardev socket,path="/run/windows-tpm/tpm.sock",id=swtpm \
    -chardev spicevmc,name=vdagent,id=vdagent \
    -blockdev driver=raw,file.driver=file,file.filename="/usr/share/ovmf/x64/OVMF_CODE.secboot.fd",$driveflags_ro,node-name=ovmf-code \
    -blockdev driver=raw,file.driver=file,file.filename="/usr/local/lib/windows/ovmf_vars.fd",$driveflags_rww,node-name=ovmf-vars \
    -blockdev driver=raw,file.driver=file,file.filename="/mnt/storage/Archive/Software/ISO Images/Win11_English_x64.iso",$driveflags_ro,node-name=cd-win-install \
    -blockdev driver=raw,file.driver=file,file.filename="/var/lib/libvirt/images/virtio-win.iso",$driveflags_ro,node-name=cd-win-virtio \
    -blockdev driver=raw,file.driver=file,file.filename="/mnt/testingfs/qemu/usbstick.img",$driveflags_rwd,node-name=drive-usb \
    -blockdev driver=raw,file.driver=host_device,file.filename="/dev/mapper/windows",$driveflags_rwd,node-name=drive-system \
    -blockdev driver=raw,file.driver=host_device,file.filename="/dev/mapper/testing-vm2",$driveflags_rwd,node-name=drive-testing2 \
    -netdev tap,ifname=tap-windows,script=no,downscript=no,vhost=on,id=netdev \
    -tpmdev emulator,chardev=swtpm,id=tpmdev \
    -audiodev pa,server="/run/user/1000/pulse/native",$audioflags,id=audiodev \
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
    -device scsi-hd,drive=drive-system,bus=scsi.0,rotation_rate=1,$scsiflags4k,id=scsi-drive-system \
    -device scsi-hd,drive=drive-testing2,bus=scsi.0,rotation_rate=1,$scsiflags4k,id=scsi-drive-testing2 \
    -device ahci,id=ahci1 -device ahci,id=ahci2 \
    -device ide-cd,drive=cd-win-install,bus=ahci1.0,id=ide-win-install \
    -device ide-cd,drive=cd-win-virtio,bus=ahci2.0,id=ide-win-virtio \
    \
    -device virtio-mouse-pci,bus=pcie.0,id=mouse \
    -device virtio-keyboard-pci,bus=pcie.0,id=kbd \
    -device virtio-balloon,bus=pcie.0,id=balloon \
    -device virtio-rng-pci,bus=pcie.0,rng=urng,id=rng \
    -device virtio-serial-pci,bus=pcie.0,id=serial \
    -device ivshmem-plain,bus=pcie.0,memdev=ivshmem-mem,id=ivshmem \
    -device virtserialport,chardev=qga,name=org.qemu.guest_agent.0,id=serial-qga \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0,id=serial-spice \
    -device tpm-tis,tpmdev=tpmdev,id=tpm-tis \
    -device intel-hda,bus=pcie.0,msi=on,id=hda \
    -device hda-duplex,audiodev=audiodev,id=hdad \
    \
    -device qemu-xhci,bus=pcie.0,p2=15,p3=15,id=xhci \
    -device usb-storage,bus=xhci.0,port=1,drive=drive-usb,$scsiflags4k,id=usb-stick \
    "${@:3}"
