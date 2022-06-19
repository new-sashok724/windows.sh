#!/bin/bash
# sashok724 was here
set -euo pipefail

source '/usr/local/bin/vfio-rebind.sh' # Also sources windows_common.sh

# Limit system slices to certain CPUs
#exitcode=0; update_system_slices "$system_slices_cpus_limited" || exitcode=$?
#if [[ $exitcode -ne 0 ]]; then
#    echo "Unexpected exit code (update_system_slices): $exitcode"
#fi
