#!/bin/bash
# sashok724 was here
set -euo pipefail
source '/usr/local/bin/scripts/windows_common.sh'

# Allow system slices to use all CPUs again
#exitcode=0; update_system_slices "$system_slices_cpus_initial" || exitcode=$?
#if [[ $exitcode -ne 0 ]]; then
#    echo "Unexpected exit code (update_system_slices): $exitcode"
#fi
