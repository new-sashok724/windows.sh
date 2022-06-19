#!/bin/bash
# sashok724 was here
set -euo pipefail
source '/usr/local/bin/scripts/windows_common.sh'

# CPU flags (too long to write them inplace)
# Took full enlightenments list from QEMU doc (https://www.qemu.org/docs/master/system/i386/hyperv.html)
# hv-passthrough is also an option to enable them all, but it may cause bugs with unstable enlighenments, and also ignores hv-vendor-id
# hv-reenlightenment is not enabled because nested virtualization is disabled (because of AVIC on Linux 5.18-)
# x2apic is off because it does not work with AVIC? (Linux 5.18)
readonly cpufeatures=+topoext,+invtsc,host-cache-info=on,l3-cache=on,x2apic=off
readonly hvflags1=hv-relaxed,hv-vapic,hv-spinlocks=0x1fff,hv-vpindex,hv-runtime,hv-crash,hv-time,hv-synic,hv-stimer,hv-tlbflush,hv-ipi
readonly hvflags2=hv-reset,hv-frequencies,hv-stimer-direct,hv-avic,hv-no-nonarch-coresharing=on
readonly hvflags_unsupported=hv-syndbg,hv-xmm-input,hv-tlbflush-ext
readonly hvflags_unsupported_nested=hv-evmcs,hv-emsr-bitmap,hv-tlbflush-direct
readonly hvflags_nested=hv-reenlightenment
readonly hvflags=$hvflags1,$hvflags2,hv-vendor-id=oknvidia

# Devices flags (to not duplicate them)
readonly driveflags_=file.aio=io_uring,discard=unmap,detect-zeroes=unmap
readonly driveflags_ro=$driveflags_,read-only=on,cache.direct=off
readonly driveflags_rw=$driveflags_,read-only=off
readonly driveflags_rwd=$driveflags_rw,cache.direct=on
readonly driveflags_rww=$driveflags_rw,cache.direct=off
readonly scsiflags4k=physical_block_size=4096,logical_block_size=4096

# Device options
readonly audioout='Starship/Matisse\ HD\ Audio\ Controller\ Digital\ Stereo \(IEC958\)'
readonly audioin='RODE\ NT-USB\ Analog\ Stereo'
readonly audioconfig="out.connect-ports=$audioout,in.connect-ports=$audioin"

# Currently unneeded:
#-object input-linux,evdev='/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse',id=imouse \
#-object input-linux,evdev='/dev/input/by-id/usb-LEOPOLD_LEO_98Keyboard-event-kbd',grab_all=on,repeat=on,id=ikbd \
#-device scsi-cd,drive=cd-arch,bus=scsi.0,id=scsi-cd-arch \
#-device usb-audio,bus=xhci.0,port=1,audiodev=audiodev,id=usb-audio \
#-device e1000,bus=pcie.0,mac=10:56:f2:d7:6f:9b,netdev=netdev,id=net \

# KVMFR permissions fix
readonly kvmfr='/dev/kvmfr0'
chown root:kvm -- "$kvmfr"
chmod 0660 -- "$kvmfr"

# Redirect audio to the main user account
export PIPEWIRE_RUNTIME_DIR='/run/user/1000'
export PIPEWIRE_LATENCY='256/48000'

# Actually launch QEMU
LD_PRELOAD='/usr/lib/libjemalloc.so' qemu-system-x86_64 -no-user-config -nodefaults \
    -name guest=qemuwin,debug-threads=on -msg timestamp=on \
    -qmp unix:'/run/windows/qmp.sock',server,nowait \
    -monitor unix:'/run/windows/monitor.sock',server,nowait \
    -spice addr=127.0.0.1,port=5900,disable-ticketing=on,seamless-migration=off \
    \
    -machine q35,dump-guest-core=off,mem-merge=off,vmport=off,pflash0=ovmf-code,pflash1=ovmf-vars \
    -accel kvm,kernel-irqchip=on -no-hpet \
    -global kvm-pit.lost_tick_policy=discard -global ICH9-LPC.disable_s3=1 \
    -cpu host,check,enforce,migratable=no,kvm=on,$cpufeatures,$hvflags \
    -smp $((cpus*2)),sockets=1,cores=$cpus,threads=2 \
    -mem-prealloc -m $ramsize -overcommit cpu-pm=on,mem-lock=on \
    -vga none -display none -serial none -parallel none \
    -boot menu=on,strict=on,order=dc,splash='/usr/local/etc/windows/splash.bmp',splash-time=30000 -rtc base=utc,clock=host,driftfix=slew \
    \
    -object iothread,id=thread-scsi \
    -object rng-random,filename='/dev/urandom',id=urng \
    -object memory-backend-file,mem-path="$kvmfr",size=128M,share=on,id=ivshmem-mem \
    -blockdev driver=raw,file.driver=file,file.filename='/usr/share/ovmf/x64/OVMF_CODE.secboot.fd',$driveflags_ro,node-name=ovmf-code \
    -blockdev driver=raw,file.driver=file,file.filename='/usr/local/lib/windows/ovmf_vars.fd',$driveflags_rww,node-name=ovmf-vars \
    -blockdev driver=raw,file.driver=file,file.filename='/mnt/storage/Archive/Software/ISO Images/Win10_21H2_English_x64.iso',$driveflags_ro,node-name=cd-win-install \
    -blockdev driver=raw,file.driver=file,file.filename='/var/lib/libvirt/images/virtio-win.iso',$driveflags_ro,node-name=cd-win-virtio \
    -blockdev driver=raw,file.driver=host_device,file.filename='/dev/mapper/windows',$driveflags_rwd,node-name=drive-system \
    -blockdev driver=raw,file.driver=host_device,file.filename='/dev/mapper/testing-vm2',$driveflags_rwd,node-name=drive-testing2 \
    -blockdev driver=raw,file.driver=file,file.filename='/mnt/testingfs/qemu/usbstick.img',$driveflags_rwd,node-name=drive-usb \
    -chardev socket,path='/run/windows-tpm/tpm.sock',id=swtpm \
    -chardev socket,path='/run/windows/qga.sock',server=on,wait=off,name=qga,id=qga \
    -chardev spicevmc,name=vdagent,id=vdagent \
    -netdev tap,ifname=tap-windows,script=no,downscript=no,vhost=on,id=netdev \
    -tpmdev emulator,chardev=swtpm,id=tpmdev \
    -audiodev jack,out.client-name=Windows,in.client-name=Windows,"$audioconfig",id=audiodev-jack \
    -audiodev spice,id=audiodev-spice \
    \
    -device virtio-scsi-pci,bus=pcie.0,num_queues=8,iothread=thread-scsi,id=scsi \
    -device virtio-net-pci,bus=pcie.0,netdev=netdev,mac=10:56:f2:d7:6f:9b,mq=on,vectors=18,id=net \
    -device scsi-hd,drive=drive-system,bus=scsi.0,rotation_rate=1,$scsiflags4k,id=scsi-drive-system \
    -device scsi-hd,drive=drive-testing2,bus=scsi.0,rotation_rate=1,$scsiflags4k,id=scsi-drive-testing2 \
    -device ahci,id=ahci1 -device ahci,id=ahci2 \
    -device ide-cd,drive=cd-win-install,bus=ahci1.0,id=ide-win-install \
    -device ide-cd,drive=cd-win-virtio,bus=ahci2.0,id=ide-win-virtio \
    -device qxl-vga,bus=pcie.0,vgamem_mb=64,id=gpu-qxl \
    \
    -device virtio-mouse-pci,bus=pcie.0,id=mouse \
    -device virtio-keyboard-pci,bus=pcie.0,id=kbd \
    -device virtio-balloon,bus=pcie.0,id=balloon \
    -device virtio-rng-pci,bus=pcie.0,rng=urng,id=rng \
    -device virtio-serial-pci,bus=pcie.0,id=serial \
    -device virtserialport,chardev=qga,name=org.qemu.guest_agent.0,id=serial-qga \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0,id=serial-spice \
    -device tpm-tis,tpmdev=tpmdev,id=tpm-tis \
    -device ivshmem-plain,bus=pcie.0,memdev=ivshmem-mem,id=ivshmem \
    -device intel-hda,bus=pcie.0,msi=on,id=hda-jack \
    -device hda-duplex,audiodev=audiodev-jack,id=hda-jack-duplex \
    -device hda-duplex,audiodev=audiodev-spice,id=hda-spice-duplex \
    \
    -device qemu-xhci,bus=pcie.0,p2=15,p3=15,id=xhci \
    -device usb-storage,bus=xhci.0,port=1,drive=drive-usb,$scsiflags4k,id=usb-stick \
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
    "$@" &

# Remember QEMU PID
readonly qemupid=$!
echo "QEMU PID: $qemupid"

# Wait for QEMU to exit, also updating thread pins every 5 seconds
# EDIT: Disabled because causes 2x worse performance. Needs investigation why
#while true; do
#    exitcode=0; qemu_cpu_pin "$qemupid" || exitcode=$?
#    if (( exitcode != 0 )); then
#        echo 'QEMU CPU Pin exit code: $exitcode'
#        break
#    fi
#    sleep 5
#done

# Wait for QEMU to exit, in case check above fails earlier
exitcode=0; wait "$qemupid" || exitcode=$?
echo "QEMU exit code: $exitcode"
