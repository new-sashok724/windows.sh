#!/bin/bash
# sashok724 was here
set -euo pipefail
source '/usr/local/bin/scripts/windows_common.sh'

if [ $EUID -ne 0 ] || [ $UID -ne 0 ] && [ $UID -ne 1000 ]; then
    echo "You forgot sudo, bitch"
    exit 1
fi

# Unbind USB
pci_rebind '0000:07:00.0' 'vfio-pci' 'xhci_hcd'
pci_rebind '0000:08:00.0' 'vfio-pci' 'xhci_hcd'
pci_rebind '0000:09:00.0' 'vfio-pci' 'xhci_hcd'
pci_rebind '0000:0a:00.0' 'vfio-pci' 'xhci_hcd'

# Unbind GPU
pci_rebind '0000:14:00.0' 'vfio-pci' 'nvidia' # Will fail if nvidia module is unloaded, but it is OK
pci_rebind '0000:14:00.1' 'vfio-pci' 'snd_hda_intel'

# Load GPU modules
echo 'Loading GPU modules'
modprobe nvidia_drm
modprobe nvidia_uvm
