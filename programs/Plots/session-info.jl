"""
Prints session info for reproducibility
"""
function sessioninfo(; show_versions=true, show_loaded = false)
    println("-- Julia Version Info --")
    versioninfo(verbose=false)

    println("\n-- Active Environment --")
    println(Base.active_project())

    deps = Pkg.dependencies()
    attached = Dict{String, VersionNumber}()
    loaded   = Dict{String, VersionNumber}()

    # --- Get attached packages from active project ---
    for (uuid, pkg) in deps
        if pkg.is_direct_dep && pkg.version !== nothing
            attached[pkg.name] = pkg.version
        end
    end

    # --- Get loaded modules (namespace only) ---
    lm = Base.loaded_modules_array()
    for m in lm
        name = string(Base.moduleroot(m))
        if haskey(deps, Base.PkgId(m).uuid)
            pkg = deps[Base.PkgId(m).uuid]
            if !haskey(attached, pkg.name) && pkg.version !== nothing
                loaded[pkg.name] = pkg.version
            end
        end
    end

    # --- Helper for attached packages (one per line) ---
    function print_attached_list(title::String, pkgs::Dict{String, VersionNumber})
        println("\n$title")
        names = sort(collect(keys(pkgs)))
        for n in names
            if show_versions
                println(" - $(n) ($(pkgs[n]))")
            else
                println(" - $(n)")
            end
        end
    end

    # --- Helper for loaded packages (grouped, old format) ---
    function print_loaded_list(title::String, pkgs::Dict{String, VersionNumber})
        println("\n$title")
        names = sort(collect(keys(pkgs)))
        for i in 1:7:length(names)
            group = names[i:min(i+6, end)]
            if show_versions
                println(join(["$(n) ($(pkgs[n]))" for n in group], ", "))
            else
                println(join(group, ", "))
            end
        end
    end

    print_attached_list("-- 📦 Attached Packages --", attached)
    if show_loaded
        print_loaded_list("-- 🔹 Loaded via Namespace (not attached) --", loaded)
    end
end
