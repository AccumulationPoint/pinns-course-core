# Workload exercised while building the display system image. PackageCompiler
# runs this file and traces which methods execute, so they get compiled INTO the
# .so — that is what makes the first plot instant. Each step is wrapped so a
# headless-rendering hiccup in the build can't abort the image build; the
# packages themselves are baked regardless (so `using` is instant either way).

try
    using Plots
    Plots.default(show = false)
    p = plot(1:10, (1:10) .^ 2; title = "warmup", xlabel = "x", ylabel = "y", label = "sq")
    plot!(p, 1:10, sqrt.(1:10); label = "sqrt", ls = :dash)
    Plots.png(p, joinpath(tempdir(), "warmup_plots.png"))
catch e
    @warn "Plots workload step failed (non-fatal — package still baked)" exception = (e, catch_backtrace())
end

try
    using CairoMakie
    f = CairoMakie.Figure()
    ax = CairoMakie.Axis(f[1, 1]; title = "warmup", xlabel = "x", ylabel = "y")
    CairoMakie.lines!(ax, 1:10, rand(10))
    CairoMakie.scatter!(ax, 1:10, rand(10))
    CairoMakie.save(joinpath(tempdir(), "warmup_makie.png"), f)
catch e
    @warn "CairoMakie workload step failed (non-fatal — package still baked)" exception = (e, catch_backtrace())
end

using IJulia
