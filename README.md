# windows.sh
My configuration and other files for QEMU to launch Windows VM with GPU passthrough (VFIO)

Hardware:
```
CPU: Ryzen 3950X
Mobo: Asus X570 Hero WiFi
RAM: 4x16 GB (64GB) @ 3600MHz CL16
GPU (Host): RX 5700 XT
GPU (Guest): GTX 1080 Ti
```

/etc/modules-load.d/kvmfr.conf:
```
kvmfr
```

/etc/modprobe/kvm.conf:
```
# kvm_amd avic is incompatible with nested (TODO Enable back on 5.19+)
# vhost_net experimental_zcopytx causes host lockup under high bandwidth load

options kvm ignore_msrs=N report_ignored_msrs=Y
options kvm_amd avic=1 nested=0
options vfio_pci ids=10de:1b06,10de:10ef,1912:0015 disable_vga=1
#options vhost_net experimental_zcopytx=1
softdep nvidia pre: vfio_pci
```

/etc/modprobe/kvmfr.conf:
```
options kvmfr static_size_mb=128
```

/etc/udev/rules.d/20-kvmfr.conf:
```
SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"
```

Specials:
* Found many useful flags in other configurations, as well as in qemu official doc
* AVIC, CPU-PM and preallocated RAM are enabled to reduce latency
* KVM state is not hidden, since NVidia allowed using their GPUs in VMs recently
* VirtIO devices are used for anything that can be paravirtualized
* kvmfr module is used for creating IVSHMEM device
* QXL display can be viewed until GPU is initialized
* Spice and JACK audio devices are both working perfectly with no stuttering
* Separate physical USB controller is also passed through; qemu-xhci is buggy when used with multiple same devices (e.g. with Valve HMD controllers)
* Secure boot and TPM2 are enabled
