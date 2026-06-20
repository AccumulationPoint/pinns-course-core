#!/bin/bash
# Boot the Julia kernel from the course display system image if it's present,
# else fall back to plain Julia so the kernel ALWAYS starts — a missing or
# unreadable image can never lock you out, and the course packages still load
# from the precompiled depot cache (just without the instant-first-plot boost).
set -euo pipefail
SYS=/opt/julia-depot/sysimages/course-1.12.so
JULIA=/opt/julia/bin/julia
if [ -r "$SYS" ]; then
    exec "$JULIA" -J "$SYS" "$@"
else
    exec "$JULIA" "$@"
fi
