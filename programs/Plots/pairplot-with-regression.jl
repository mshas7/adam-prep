using PairPlots, CairoMakie, DataFrames, Statistics, GLM, ColorSchemes

"""
    pairplot_with_regression(df; alpha=0.2, color=:red)

# Arguments
- `df::DataFrame`: Input data frame (numeric columns recommended).
- `alpha`: Transparency for the CI band (default = 0.2).
- `color`: Color of the regression line and CI band (default = :red).
- `title`
- `subtitle`
- `size`
"""
function pairplot_with_regression(df::DataFrame; alpha=0.2, color=:red, size=nothing, title="", subtitle="", footnotes="")
    # --- Select numeric columns only
    numeric_cols = [n for (n, c) in zip(names(df), eachcol(df)) if eltype(c) <: Number]
    df_num = df[:, numeric_cols]

    # --- Create base pairplot
    if size === nothing
        fig = Figure()
    else
        fig= Figure(size=size)
    end

    corr(x, y) = StatsBase.cor(x, y) # Pearson Correlation - defining function because, we want the label as corr not cor

    pairplot(
        fig[1,1:3],
        df_num => (
            PairPlots.Scatter(markersize=7.5, alpha=0.4, color=:black),
            # PairPlots.TrendLine(color=:black),
            # PairPlots.PearsonCorrelation(fontsize=14, color=color),
            # PairPlots.MarginHist(color=:gray75),
            PairPlots.MarginDensity(
                  color=:black,
                  linewidth=1.5f0
            ),
            PairPlots.Calculation( 
                corr,
                fontsize=14, 
                color=:black
            )
        ),
        fullgrid=false,
        bodyaxis = (; 
            xgridvisible = true, 
            ygridvisible = true,
            xticklabelrotation = 0,   
            yticklabelrotation = 0      
        ),    
        diagaxis = (; 
            xgridvisible = true, 
            ygridvisible = true,
            xticklabelrotation = 0,   
            yticklabelrotation = 0      
        ),
    )

    # --- Collect all axes manually
    all_axes = [obj for obj in fig.content if obj isa Makie.Axis]

    # Helper: find axis with given (xcol, ycol) based on titles
    function find_axis(xname, yname)
        for ax in all_axes
            xtitle = ax.xlabel[] isa String ? ax.xlabel[] : string(ax.xlabel[])
            ytitle = ax.ylabel[] isa String ? ax.ylabel[] : string(ax.ylabel[])
            if xtitle == xname && ytitle == yname
                return ax
            end
        end
        return nothing
    end

    # --- Loop through all column pairs
    for (i, colx) in enumerate(numeric_cols)
        for (j, coly) in enumerate(numeric_cols)
            if i == j
                continue  # skip diagonal
            end

            ax = find_axis(colx, coly)
            isnothing(ax) && continue

            x = df_num[!, colx]
            y = df_num[!, coly]

            # Fit linear regression
            fits = fit(LinearModel, @formula(y ~ x), DataFrame(x=x, y=y))
            β0, β1 = coef(fits)
            x_sorted = sort(x)
            y_pred = β0 .+ β1 .* x_sorted

            # Compute 95% CI

            n = length(x)

            # Residual standard deviation estimated from model deviance with (n - 2) degrees of freedom
            σ = sqrt(deviance(fits) / (n - 2))

            # Mean of the predictor x
            mean_x = mean(x)

            # Sum of squares of x around its mean
            Sxx = sum((x .- mean_x).^2)

            # Standard error for each prediction:
            se = σ .* sqrt.(1/n .+ (x_sorted .- mean_x).^2 ./ Sxx)

            # 95% confidence interval for predictions
            ci_upper = y_pred .+ 1.96 .* se 
            ci_lower = y_pred .- 1.96 .* se

            # Overlay regression line and CI band
            band!(ax, x_sorted, ci_lower, ci_upper, color=(color, alpha))
            lines!(ax, x_sorted, y_pred, color=color, linewidth=2)
        end
    end

    if title != ""
        Label(
            fig[0,2],
            title,
            fontsize=20,
            font = :bold
        )
    end

    if subtitle != ""
        Label(
            fig[0,2],
            "\n\n\n$subtitle",
            fontsize=14,
            font = :regular
        )
        rowsize!(fig.layout, 1, Relative(0.95))
        rowsize!(fig.layout, 0, Relative(0.05))
    end

    if footnotes != ""
        Label(
            fig[end+1, :],
            "$footnotes",
            fontsize=14,
            font = :regular,
            halign = :left
        )
        rowsize!(fig.layout, 1, Relative(0.90))
        rowsize!(fig.layout, 0, Relative(0.075))
        rowsize!(fig.layout, 2, Relative(0.025))
    end

    return fig
end