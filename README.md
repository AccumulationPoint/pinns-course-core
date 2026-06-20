# pinns-course-core

The **take-it-home Docker image** for the AIMS [Physics-Informed Neural Networks
(PINN) course](https://open-aims.github.io/Julia_PINN_training_2026/). It bundles
the course's Julia + Python software stack — already **precompiled** — plus a copy
of the course materials, so you can run the whole course on your own computer with
a single command.

```bash
docker run --rm -p 8888:8888 ghcr.io/accumulationpoint/pinns-course-core
```

Then open the printed `http://127.0.0.1:8888/lab` link. You get JupyterLab with a
**Julia 1.12** kernel and a **Python 3** kernel, the precompiled `@pinn` course
environment (so `using NeuralPDE` works out of the box), and the course materials
under `~/course-materials`.

> This is the same software stack the course's cloud JupyterHub uses, packaged so
> it keeps working **after** the cloud servers are switched off. The image is the
> durable artifact; the cloud hub is temporary (course participants only).

## What's inside

- **Julia 1.12** with the pinned course environment **`@pinn`** — `NeuralPDE`,
  `ModelingToolkit`, `MethodOfLines`, `Optimization`, `OrdinaryDiffEq`, `Lux`,
  `Zygote`, `Plots`, `CairoMakie`, `MLJ`, … (see [`Project.toml`](Project.toml)).
  This is the **CPU** package set — the GPU packages (`CUDA`, `LuxCUDA`, `cuDNN`)
  are intentionally left out, since most laptops have no NVIDIA GPU.
- **A portable display system image** (`course-1.12.so`) baked in, so the Julia
  kernel starts ready to plot — first `plot()` is instant.
- **Python 3** with PyTorch / JAX (CPU builds), NumPy / SciPy / pandas /
  scikit-learn / Matplotlib, and JupyterLab (see [`requirements.txt`](requirements.txt)).
- The **course materials** (`~/course-materials`) and two **welcome notebooks**.

`using NeuralPDE` loads from the precompiled cache, so the first PINN run is about
a minute (≈20 s to load + ≈50 s to compile the first solve), then instant. See the
course's [The `@pinn` Julia environment](https://open-aims.github.io/Julia_PINN_training_2026/units/pinn_env/pinn_env.html)
appendix for the full story on environments, precompilation, and the depot.

## Keeping your work

`--rm` makes the container disposable. To keep files you create, mount a folder:

```bash
docker run --rm -p 8888:8888 -v "$PWD/work:/home/jovyan/work" \
  ghcr.io/accumulationpoint/pinns-course-core
```

Anything you save under `~/work` in JupyterLab is written to a `work/` folder next
to where you ran the command.

## Notes

- **CPU-only.** Fine for every exercise in the course — only slower on the larger
  training runs.
- **Apple-Silicon Macs (M1–M4):** the image is built for x86-64; Docker Desktop
  runs it through its built-in emulation layer (no extra setup, just slower).
- **Disk:** allow ~12 GB of free space (the image unpacks larger than it downloads,
  and the baked system image adds ~1.5 GB).
- **Updating:** `docker pull ghcr.io/accumulationpoint/pinns-course-core` before
  running grabs the latest build.

## How it's built

Everything needed to build the image is in this repo:
[`Dockerfile`](Dockerfile), [`Project.toml`](Project.toml),
[`requirements.txt`](requirements.txt), [`entrypoint.sh`](entrypoint.sh),
[`julia-kernel.sh`](julia-kernel.sh) (the kernel launcher), and
[`sysimage_workload.jl`](sysimage_workload.jl) (the workload baked into the system
image). A GitHub Actions workflow ([`.github/workflows/build.yml`](.github/workflows/build.yml))
builds it, CPU-smoke-tests it, and pushes to
`ghcr.io/accumulationpoint/pinns-course-core` on every change.

To build it yourself:

```bash
docker build -t pinns-course-core .
```

## License / attribution

Built for the AIMS PINN course by [Accumulation Point](https://www.accumulationpoint.com).
Course materials live in [`open-AIMS/Julia_PINN_training_2026`](https://github.com/open-AIMS/Julia_PINN_training_2026).
