# syntax=docker/dockerfile:1
#
# pinns-course-core — the "take-it-home" laptop image for the AIMS Physics-
# Informed Neural Networks (PINN) course. Bundles the same Julia + Python course
# stack and the course materials, so you can run the whole course on your own
# computer with one command:
#
#     docker run --rm -p 8888:8888 ghcr.io/accumulationpoint/pinns-course-core
#     # then open the printed http://127.0.0.1:8888/lab URL
#
# Design goals:
#   - Mirrors the course's `@pinn` environment: Julia 1.12 + the pinned course
#     packages, precompiled, so `using NeuralPDE` works out of the box.
#   - CPU-PORTABLE: Julia codegen is multiversioned (JULIA_CPU_TARGET) so the
#     precompiled depot AND the system image run on any x86-64 laptop, Intel or
#     AMD. (Apple-Silicon Macs run it under Docker Desktop's emulation layer.)
#   - SAME ENV MODEL the course uses: a read-only shared `@pinn` base env stacked
#     under the user's own writable env, so `using` finds course packages and a
#     user's `Pkg.add(...)` lands in their home.
#
# CPU-only (most laptops have no NVIDIA GPU); PyTorch / JAX are CPU builds. The
# GPU packages (CUDA, LuxCUDA, cuDNN) are intentionally NOT in this image.

FROM ubuntu:22.04

ARG JULIA_VERSION=1.12.6
# Official Julia multiversioned target: generic baseline + sandybridge/haswell
# (AVX2) variants with runtime dispatch — the common subset every x86-64 CPU runs.
ARG JULIA_CPU_TARGET="generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)"
ARG COURSE_REPO=https://github.com/open-AIMS/Julia_PINN_training_2026.git
ARG COURSE_REF=main

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    SHARED_DEPOT=/opt/julia-depot

# --- OS packages -----------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git build-essential \
      python3 python3-pip python3-dev \
      tini \
 && rm -rf /var/lib/apt/lists/*

# --- Julia 1.12 ------------------------------------------------------------
RUN set -eux; \
    series="$(echo "${JULIA_VERSION}" | cut -d. -f1-2)"; \
    curl -fsSL "https://julialang-s3.julialang.org/bin/linux/x64/${series}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" -o /tmp/julia.tgz; \
    mkdir -p /opt/julia; \
    tar -xzf /tmp/julia.tgz -C /opt/julia --strip-components=1; \
    ln -sf /opt/julia/bin/julia /usr/local/bin/julia; \
    rm /tmp/julia.tgz; \
    julia --version

# --- Python scientific stack ----------------------------------------------
# Torch/torchvision pinned to the CPU wheel index (this image is CPU-only; the
# default PyPI torch drags in ~2 GB of CUDA libs a laptop can't use).
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir --upgrade pip \
 && python3 -m pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu \
      torch torchvision \
 && python3 -m pip install --no-cache-dir -r /tmp/requirements.txt

# --- Julia @pinn base env (precompiled into the shared read-only depot) -----
# Resolve + precompile the pinned course Project.toml on Julia 1.12 into a shared
# depot. JULIA_CPU_TARGET is set for this step so the precompiled package images
# are portable across x86-64 laptops; leaving it unset at runtime lets a user's
# own Pkg.add compile natively (fast).
COPY Project.toml ${SHARED_DEPOT}/environments/pinn/
RUN set -eux; \
    export JULIA_DEPOT_PATH="${SHARED_DEPOT}"; \
    export JULIA_CPU_TARGET="${JULIA_CPU_TARGET}"; \
    export JULIA_NUM_PRECOMPILE_TASKS="$(nproc)"; \
    julia --project="${SHARED_DEPOT}/environments/pinn" -e ' \
      using Pkg; \
      Pkg.Registry.add("General"); \
      Pkg.resolve(); \
      Pkg.instantiate(); \
      Pkg.precompile(); \
      import IJulia; \
      @info "pinn env baked" ndeps=length(keys(Pkg.project().dependencies))'; \
    chmod -R a+rX "${SHARED_DEPOT}"

# --- Portable display system image (instant first plot / kernel start) ------
# A system image is a single `.so` (a shared-object / native-library file) with
# the Julia runtime AND a chosen set of packages already loaded and machine-coded
# inside it, mmap'd at kernel start. We bake the *display* set — Plots, CairoMakie,
# IJulia — so first plot is instant. (Only the display set builds *portably*; the
# heavy SciML stack cannot be baked into a portable image, so it loads from the
# precompiled depot cache instead.) PackageCompiler lives in a throwaway env so it
# never pollutes @pinn; it's GC'd afterwards to keep the image lean.
COPY sysimage_workload.jl /tmp/sysimage_workload.jl
RUN set -eux; \
    export JULIA_DEPOT_PATH="${SHARED_DEPOT}"; \
    export JULIA_CPU_TARGET="${JULIA_CPU_TARGET}"; \
    mkdir -p "${SHARED_DEPOT}/sysimages"; \
    julia --project="${SHARED_DEPOT}/environments/pkgc" -e ' \
      using Pkg; Pkg.add(name="PackageCompiler"); \
      using PackageCompiler; \
      create_sysimage(["Plots", "IJulia"]; \
        sysimage_path = "/opt/julia-depot/sysimages/course-1.12.so", \
        project = "/opt/julia-depot/environments/pinn", \
        precompile_execution_file = "/tmp/sysimage_workload.jl", \
        cpu_target = ENV["JULIA_CPU_TARGET"])'; \
    test -r /opt/julia-depot/sysimages/course-1.12.so; \
    rm -rf "${SHARED_DEPOT}/environments/pkgc"; \
    julia -e 'using Pkg, Dates; Pkg.gc(collect_delay=Hour(0))' || true; \
    chmod -R a+rX "${SHARED_DEPOT}/sysimages"

# Jupyter kernel -> launcher that boots from the system image (with a plain-Julia
# fallback if the image is ever missing/unreadable, so the kernel always starts).
COPY --chmod=0755 julia-kernel.sh /usr/local/bin/julia-kernel.sh
RUN mkdir -p /usr/local/share/jupyter/kernels/julia-1.12 && \
    printf '%s\n' \
      '{' \
      '  "display_name": "Julia 1.12",' \
      '  "argv": ["/usr/local/bin/julia-kernel.sh", "-i", "--color=yes",' \
      '           "-e", "import IJulia; IJulia.run_kernel()", "{connection_file}"],' \
      '  "language": "julia",' \
      '  "interrupt_mode": "signal"' \
      '}' > /usr/local/share/jupyter/kernels/julia-1.12/kernel.json

# --- non-root user + course materials --------------------------------------
RUN useradd -m -s /bin/bash -u 1000 jovyan
ARG COURSE_REPO
ARG COURSE_REF
RUN git clone --depth 1 --branch "${COURSE_REF}" "${COURSE_REPO}" /home/jovyan/course-materials \
 && rm -rf /home/jovyan/course-materials/.git \
 && chown -R jovyan:jovyan /home/jovyan

# Welcome notebooks (canonical copies live in this repo).
COPY --chown=jovyan:jovyan welcome_julia.ipynb welcome_python.ipynb /home/jovyan/

# Stacked env: user's own depot first (writable) + shared course depot second
# (read-only); @pinn stacked under the user's env -> course pkgs `using`-able,
# Pkg.add lands in the user's home.
ENV JULIA_DEPOT_PATH=/home/jovyan/.julia:/opt/julia-depot \
    JULIA_LOAD_PATH=@:@v#.#:@pinn:@stdlib

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER jovyan
WORKDIR /home/jovyan
EXPOSE 8888

ENTRYPOINT ["tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", \
     "--ServerApp.token=", "--ServerApp.password=", "--ServerApp.root_dir=/home/jovyan"]
