#!/bin/bash
# sashok724 was here
set -euo pipefail

function pci_rebind() {
    device_id="$1"
    driver_from="$2"
    driver_to="$3"

    driver_link=$(readlink "/sys/bus/pci/devices/$device_id/driver") || driver_link=''
    [ ! -z "$driver_link" ] && driver=$(basename "$driver_link") || driver=''
    if [ "$driver" = "$driver_from" ] || [ -z "$driver" ]; then
        echo "$device_id: Rebinding $driver_from -> $driver_to"
        if [ ! -z "$driver" ]; then
            echo "$device_id" > "/sys/bus/pci/drivers/$driver/unbind"
        fi
        (echo "$device_id" > "/sys/bus/pci/drivers/$driver_to/bind") || true
    elif [ "$driver" = "$driver_to" ]; then
        echo "$device_id: Already correctly bound"
    else
        echo "$device_id: Unknown driver $driver"
    fi
}
