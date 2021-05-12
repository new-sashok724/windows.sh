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

/etc/modprobe/kvm.conf:
```
options kvm ignore_msrs=N report_ignored_msrs=Y
options vfio-pci ids=10de:1b06,10de:10ef,1912:0015
options vhost_net experimental_zcopytx=1
```

Specials:
* Found many useful flags in other configurations, as well as in qemu official doc
* CPU-PM and preallocated RAM is enabled to reduce latency
* KVM state is not hidden, since NVidia allowed using their GPUs in VMs recently
* Virtio devices are used for anything that can be paravirtualized
* Separate physical USB controller is also passed through; qemu-xhci is buggy when used with multiple same devices (e.g. with Valve HMD controllers)
