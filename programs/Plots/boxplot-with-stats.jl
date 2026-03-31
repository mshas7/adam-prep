# Loading Required Packages
using CairoMakie
using Statistics, StatsBase
using DataFramesMeta
using AlgebraOfGraphics
# using PharmaDatasets
using Distributions
using CategoricalArrays

"""
    boxplot_with_stats(
    df::DataFrame, 
    groupcol::Symbol, 
    valuecol::Symbol; 
    stats::Vector{Pair{Function,String}}, 
    sigdigits::Int=2, 
    ylabel=string(valuecol), 
    xlabel=string(groupcol),
    dodge::Union{Nothing,Symbol}=nothing,
    stats_font_size::Int=12,
    dodge_label::String=string(dodge),
    legend_position::Symbol=:bottom,
    fig_size::Union{Nothing, Tuple{Int64, Int64}}=nothing,
)

Create a grouped boxplot with an accompanying table of summary statistics.

This function visualizes the distribution of a numeric variable (`valuecol`) across one or more groups (`groupcol`), 
    optionally split by a secondary grouping variable (`dodge`). Beneath the boxplot, a customizable statistics table 
    summarizes each group (and subgroup, if applicable) using user-defined summary functions.

# Arguments
- **`df::DataFrame`**  
  Input data frame containing the columns to be visualized.

- **`groupcol::Symbol`**  
  Column defining the primary grouping variable (x-axis categories).

- **`valuecol::Symbol`**  
  Column containing the numeric values to be plotted as boxplots.

- **`stats::Vector{Pair{Function,String}}`**  
  Vector of pairs defining summary statistics, e.g.  
  `[(mean => "Mean"), (median => "Median"), (std => "SD")]`.  
  Each function is applied to group (or subgroup) data, and the corresponding label is displayed in the table.
    Works with bespoke functions as well.

- **`sigdigits::Int=2`**  
  Number of significant digits to use when rounding numeric statistics.

- **`ylabel::String`**, **`xlabel::String`**  
  Axis labels. Defaults to the column names.

- **`dodge::Union{Nothing,Symbol}=nothing`**  
  Optional secondary grouping variable for creating *dodged* boxplots (side-by-side subgroups within each main group).

- **`stats_font_size::Int=12`**  
  Font size for the text displayed in the statistics table.

- **`dodge_label::String=string(dodge)`**  
  Legend title for the secondary grouping variable (only used when `dodge` is specified).

- **`legend_position::Symbol=:bottom`**  
  Specify the position of the legend, only `:top` or `:bottom` is allowed.

- **`fig_size::Tuple{Int64, Int64}`**
  Manually adjust the figure dimension. Defaults to automatic scaling based on number of groups and number of summary stats.

# Details
- When `dodge` is not provided, one boxplot is drawn per group.  
- When `dodge` is provided, each subgroup within a group is drawn as a dodged boxplot with its own color and legend entry.  
- The statistics table automatically aligns below the boxplot, displaying the computed statistics per group (or per subgroup).  
- Figure dimensions scale automatically with the number of groups and statistics to maintain readability.

# Returns
A `Figure` object (from Makie.jl) containing:
1. The grouped (or dodged) boxplot, and  
2. The summary statistics table aligned below it.
"""
function boxplot_with_stats(
    df::DataFrame, 
    groupcol::Symbol, 
    valuecol::Symbol; 
    stats::Vector{Pair{Function,String}}, 
    sigdigits::Int=2, 
    ylabel=string(valuecol), 
    xlabel=string(groupcol),
    dodge::Union{Nothing,Symbol}=nothing,
    stats_font_size::Int=12,
    dodge_label::String=string(dodge),
    legend_position::Symbol=:bottom,
    fig_size::Union{Nothing, Tuple{Int64, Int64}}=nothing,
)

    # df = dropmissing(df, valuecol)
    # === 1. Identify groups and prepare data ===
    groups = unique(df[!, groupcol])
    ngroups = length(groups)

    # Collect values for each group (used when no dodge)
    grouped_vals = [@rsubset(df, $(groupcol) == g)[!, valuecol] for g in groups]

    # Separate functions and labels for the stats table
    stat_funcs  = first.(stats)
    stat_labels = last.(stats)
    nstats      = length(stat_labels)

    # === 2. Compute figure size dynamically ===
    max_dodge = dodge === nothing ? 1 :
        maximum([length(unique(df[df[!, groupcol] .== g, dodge])) for g in groups])

    width_per_group = 70
    height_per_stat = 40
    min_width, min_height = 600, 400

    fig_width  = max(min_width,  0.7 * width_per_group * ngroups * max_dodge)
    fig_height = max(min_height, 300 + height_per_stat * nstats)

    if fig_size === nothing
        fig = Figure(size = (fig_width, fig_height))
    elseif fig_size !== nothing
        fig = Figure(size = fig_size)
    else
        @error "fig_size invalid"
    end

    # === 3. Create main boxplot axis ===
    ax = Axis(fig[1, 1],
        ylabel = ylabel,
        xlabel = xlabel,
        xticks = (1:ngroups, string.(groups)),
        ylabelfont=:bold,
        xlabelfont=:bold
    )

    # === 4. Draw boxplots ===
    if dodge !== nothing
        # Handle dodged boxplots (grouped by secondary variable)
        all_subgroups = sort(unique(df[!, dodge]))
        n_subgroups = length(all_subgroups)

        cmap = cgrad(:lightrainbow, n_subgroups, categorical=true)
        palette = [cmap[i] for i in range(0, 1, length=n_subgroups)]

        for (i, g) in enumerate(groups)
            group_rows = df[!, groupcol] .== g
            subgroups = sort(unique(df[group_rows, dodge]))
            n_sub = length(subgroups)

            width = 0.75
            dodge_gap = 0.07
            slot_width = width / (n_sub + (n_sub - 1) * dodge_gap)
            offsets = [(j - (n_sub + 1)/2) * (slot_width * (1 + dodge_gap)) for j in 1:n_sub]

            for (j, sg) in enumerate(subgroups)
                subvals = df[(df[!, groupcol] .== g) .& (df[!, dodge] .== sg), valuecol]
                subvals = collect(skipmissing(subvals))
                x_pos = i .+ offsets[j]
                color_idx = findfirst(==(sg), all_subgroups)
                boxplot!(ax, fill(x_pos, length(subvals)), subvals;
                    width = slot_width,
                    show_notch = false,
                    color = palette[color_idx],
                    strokecolor = :black
                )
            end
        end

        labels = string.(all_subgroups)
        elements = [PolyElement(polycolor = palette[i]) for i in 1:n_subgroups]
        
        if legend_position == :top
            Legend(fig[0, :], elements, labels, dodge_label, orientation = :horizontal, titleposition = :left, framevisible = false)
        elseif legend_position == :bottom
            Legend(fig[3, :], elements, labels, dodge_label, orientation = :horizontal, titleposition = :left, framevisible = false)
        else
            @warn "legend_position can only be `:top` or `:bottom`. Figure produced with no legend."
        end

    else
        # === Simple boxplot (no dodge) with group-based colors ===
        cmap = cgrad(:lightrainbow, ngroups, categorical=true)
        palette = [cmap[i] for i in range(0, 1, length=ngroups)]

        for (i, vals) in enumerate(grouped_vals)
            vals = collect(skipmissing(vals))
            boxplot!(ax, fill(i, length(vals)), vals;
                width = 1,
                show_notch = false,
                color = palette[i],
                strokecolor = :black
            )
        end
    end

    # === 5. Create statistics table axis ===
    tab_ax = Axis(fig[2, 1],
        xticks = (1:ngroups, string.(groups)),
        yticks = (1:length(stat_labels), stat_labels),
        xlabel = string(groupcol),
        yreversed = true,
        topspinevisible = false,
        leftspinevisible = false,
        rightspinevisible = false,
        bottomspinevisible = false,
        ygridvisible = false,
        yticksvisible = false,
        yticklabelsize=stats_font_size
    )
    ylims!(tab_ax, nstats + 0.6, 0.4)
    hidexdecorations!(tab_ax)
    linkxaxes!(ax, tab_ax)

    # === 6. Fill in statistics table ===
    for (row, (f, label)) in enumerate(stats)
        for (i, g) in enumerate(groups)
            if dodge === nothing
                val = f(df[df[!, groupcol] .== g, valuecol])
                    if val isa Number
                        val = string(round(val, sigdigits = sigdigits))
                    end
                text!(tab_ax, string(val), position = (i, row), align = (:center, :center), fontsize=stats_font_size)
            else
                group_rows = df[!, groupcol] .== g
                subgroups = sort(unique(df[group_rows, dodge]))
                n_sub = length(subgroups)
                width = 0.75
                dodge_gap = 0.03
                slot_width = width / (n_sub + (n_sub - 1) * dodge_gap)
                offsets = [(j - (n_sub + 1)/2) * (slot_width * (1 + dodge_gap)) for j in 1:n_sub]

                for (j, sg) in enumerate(subgroups)
                    subvals = df[(df[!, groupcol] .== g) .& (df[!, dodge] .== sg), valuecol]
                    val = f(subvals)
                        if val isa Number
                            val = string(round(val, sigdigits = sigdigits))
                        end
                    x_pos = i + offsets[j]
                    text!(tab_ax, string(val), position = (x_pos, row), align = (:center, :center), fontsize=stats_font_size)
                end
            end
        end
    end

    # === 7. Adjust layout proportions ===
    colsize!(fig.layout, 1, Auto(1.0))
    rowsize!(fig.layout, 1, Relative(0.75))
    rowsize!(fig.layout, 2, Relative(0.25))
    if dodge !== nothing && legend_position == :top
        rowsize!(fig.layout, 0, Relative(0.05))
    elseif dodge !== nothing && legend_position == :bottom
        rowsize!(fig.layout, 3, Relative(0.05))
    end
    
    return fig
end