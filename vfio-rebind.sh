#!/bin/bash
# sashok724 was here
set -euo pipefail
source '/usr/local/bin/scripts/windows_common.sh'

if [ $EUID -ne 0 ] || [ $UID -ne 0 ] && [ $UID -ne 1000 ]; then
    echo "You forgot sudo, bitch"
    exit 1
fi

# Terminate seat
loginctl terminate-seat seat-tv || true

# Bind USB
pci_rebind '0000:07:00.0' 'xhci_hcd' 'vfio-pci'
pci_rebind '0000:08:00.0' 'xhci_hcd' 'vfio-pci'
pci_rebind '0000:09:00.0' 'xhci_hcd' 'vfio-pci'
pci_rebind '0000:0a:00.0' 'xhci_hcd' 'vfio-pci'

# Unload GPU modules
echo 'Unloading GPU modules'
modprobe -r nvidia_drm || true
modprobe -r nvidia_uvm || true

# Bind GPU
pci_rebind '0000:14:00.0' 'nvidia' 'vfio-pci'
pci_rebind '0000:14:00.1' 'snd_hda_intel' 'vfio-pci'
