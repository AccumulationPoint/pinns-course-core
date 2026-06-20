#!/usr/bin/env bash
# pinns-course-core entrypoint: make sure the user's writable Julia depot exists
# (first entry in JULIA_DEPOT_PATH — the shared /opt/julia-depot is read-only),
# print a short banner, then hand off to the command (JupyterLab by default).
set -e

mkdir -p "${HOME}/.julia"

cat <<'BANNER'
======================================================================
  2026 AIMS PINN workshop — local course image (by Accumulation Point)
  * Course materials:  ~/course-materials
  * Welcome notebooks: ~/welcome_julia.ipynb, ~/welcome_python.ipynb
  * Julia kernel "Julia 1.12" and Python 3 kernel are ready.
  * `using NeuralPDE` works out of the box; `Pkg.add(...)` goes to ~/.julia
  Open the http://127.0.0.1:8888/lab link printed below.
======================================================================
BANNER

exec "$@"
