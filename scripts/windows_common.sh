#!/bin/bash
# sashok724 was here
set -euo pipefail

# VM options
readonly cpus=8
readonly ramsize=20G
declare -A cpus_pin=(
    [0]=8   [1]=24
    [2]=9   [3]=25
    [4]=10  [5]=26
    [6]=11  [7]=27
    [8]=12  [9]=28
    [10]=13 [11]=29
    [12]=14 [13]=30
    [14]=15 [15]=31
)

# CPU isolation options
system_slices=('init.scope' 'system.slice' 'machine.slice' 'user.slice')
system_slices_cpus_initial='0-31' # All CPUs
system_slices_cpus_limited='0-7,16-23'

# Common functions
function pci_rebind() {
    local -r device_id="$1"
    local -r driver_from="$2"
    local -r driver_to="$3"

    local -r driver_link="$(readlink "/sys/bus/pci/devices/$device_id/driver")" || driver_link=''
    [[ -n "$driver_link" ]] && driver="$(basename "$driver_link")" || driver=''
    if [[ "$driver" = "$driver_from" ]] || [[ -z "$driver" ]]; then
        echo "(PCI Rebind) $device_id: Rebinding $driver_from -> $driver_to"
        if [[ -n "$driver" ]]; then
            echo "$device_id" > "/sys/bus/pci/drivers/$driver/unbind"
        fi
        (echo "$device_id" > "/sys/bus/pci/drivers/$driver_to/bind") || true
    elif [[ "$driver" = "$driver_to" ]]; then
        echo "(PCI Rebind) $device_id: Already correctly bound"
    else
        echo "(PCI Rebind) $device_id: Unknown driver $driver"
    fi
}

function update_system_slices() {
    for slice in "${system_slices[@]}"; do
        echo "(Slices) $slice: Setting AllowedCPUs=$1"
        systemctl set-property --runtime -- "$slice" AllowedCPUs="$1"
    done
}

declare -A qemu_pinned=()
function qemu_cpu_pin() {
    local -r pid="$1"
    local -r pid_dir="/proc/$pid"
    if [[ ! -d "$pid_dir" ]]; then
        echo "(QEMU CPU Pin) Unknown PID: $pid"
        return 1
    fi

    # Scan all tasks, find ones that are not pinned yet
    local tid tid_comm
    for tid_dir in "$pid_dir/task"/*/; do
        tid="$(basename "$tid_dir")"
        if [[ "${qemu_pinned["$tid"]:-}" != '' ]]; then
            continue # Already pinned
        fi

        # Decide with allowed CPUs for this task
        local tid_pin="$system_slices_cpus_limited"
        tid_comm="$(cat "$tid_dir/comm")"
        if [[ "$tid_comm" =~ ^CPU\ ([0-9]+)/KVM$ ]]; then # CPU 0/KVM
            local tid_kvm_cpu="${BASH_REMATCH[1]}"
            local tid_pin_="${cpus_pin["$tid_kvm_cpu"]:-}"
            if [[ "$tid_pin_" != '' ]]; then
                tid_pin="$tid_pin_"
            fi
        fi

        # Try to pin this task to specified CPUs
        echo "(QEMU CPU Pin) Pinning '$tid_comm' ($tid) -> $tid_pin"
        local exitcode=0; taskset -pc "$tid_pin" "$tid" || exitcode=$?
        if (( exitcode != 0 )); then
            echo "(QEMU CPU Pin) Pin failed for '$tid_comm' ($tid): $exitcode"
        fi

        # Even if failed, mark as pinned; It is unlikely that it will succeed if repeated
        qemu_pinned["$tid"]="$tid_pin"
    done
}
