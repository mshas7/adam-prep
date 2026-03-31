###---------------------------------------------------------------------------
### Utility Function to Generate Key Diagnostic Plots
###---------------------------------------------------------------------------

# Definitions 
#---------------------------------------------------------------------------

# Function: gof(inspect_obj, dv_name, time_var, time_label, log_conc)
#
# inspect_obj: inspect object
# dv_name = name of the dependent variable in the dataset
# time_var = time variable to be used: time or tad 
# time_label = time label to be used in the plot: "Time from First Dose [h]" or "Time from Previous Dose [h]"
# log_conc = plot concentrations in log scale: true or false


# Create Function
#---------------------------------------------------------------------------

function gof(inspect_obj, dv_name, time_var, time_label, log_conc)

# Dynamically construct column symbols
col_obs = Symbol(dv_name)
col_pred = Symbol("$(dv_name)_pred")
col_ipred = Symbol("$(dv_name)_ipred")
col_wres = Symbol("$(dv_name)_wres")
col_iwres = Symbol("$(dv_name)_iwres")
col_time = Symbol("$time_var")

# Convert inspect element to a dataframe
inspect_df = DataFrame(inspect_obj)

# Cleanup and wrangle dataframe for AoG plot creation when needed
@rsubset!(inspect_df, !ismissing($col_obs))
@rsubset!(inspect_df, !ismissing($col_pred))
@rsubset!(inspect_df, !ismissing($col_ipred))

@rsubset!(inspect_df, $col_obs > 0)
@rsubset!(inspect_df, $col_pred > 0)
@rsubset!(inspect_df, $col_ipred > 0)

# Start of figure
fig = Figure(; size = (1000, 800), fontsize = 14)

# Figure settings toggles
ident_color = :black
smooth_color = :red
linear_color = :green
line_width = 3
markershape = :circle
markercolor = :transparent
markerstrokecolor = :blue       
markerstrokewidth = 0.5 
marker_size = 6

# Line of identity for Obs vs PRED/IPRED
concmax = maximum(vcat(inspect_df[!, col_pred], inspect_df[!, col_ipred], inspect_df[!, col_obs]))
ident = data((x = [0, concmax], y = [0, concmax])) * 
        mapping(:x, :y) * 
        visual(Lines, color = ident_color)

# Create the horizontal lines at y = -5, -2, 0, 2, 5 for CWRES/IWRES
hlines = mapping([-5,-2,0,2,5]) * 
         visual(HLines; color = :black, linestyle = :dash)

# Plot 1 - Observed vs Population Predictions 
obs_pred = data(inspect_df) * 
              mapping(col_pred, col_obs) * 
              (visual(Scatter; marker = markershape, markersize = marker_size, color = markercolor, 
              strokecolor = markerstrokecolor, strokewidth = markerstrokewidth) + 
              smooth() * visual(color = smooth_color, linewidth = line_width) + 
              AlgebraOfGraphics.linear() * visual(color = linear_color)
              )

#xtick_vals = collect(round.(range(0, concmax; length=5)))
#ytick_vals = collect(round.(range(0, concmax; length=5)))              

axis_args = (
  title="OBSERVED VS PRED",
  xlabel="Population Predicted Concentration [ng/mL]",
  ylabel="Observed Concentration [ng/mL]",
  # xticks = (xtick_vals, string.(Int.(xtick_vals))),
  # yticks = (ytick_vals, string.(Int.(ytick_vals))),
  # xticks=(0:10000:concmax, string.(Int.(round.(0:10000:concmax)))),
  # yticks=(0:10000:concmax, string.(Int.(round.(0:10000:concmax)))),
  limits = ((0, concmax),(0, concmax))
)

if log_conc 
  axis_args = merge(axis_args, (xscale = Makie.pseudolog10, yscale = Makie.pseudolog10, 
                                yticks = (10 .^ (0:5), string.(10 .^ (0:5))),
                                xticks = (10 .^ (0:5), string.(10 .^ (0:5))),))
end

g1 = draw!(fig[1,1], 
           ident + obs_pred; 
           axis = axis_args
)

# Plot 2 - Observed vs Individual Predictions
obs_ipred = data(inspect_df) * 
            mapping(col_ipred, col_obs) * 
            (visual(Scatter; marker = markershape, markersize = marker_size, color = markercolor, 
              strokecolor = markerstrokecolor, strokewidth = markerstrokewidth) + 
              smooth() * visual(color = smooth_color, linewidth = line_width) + 
              AlgebraOfGraphics.linear() * visual(color = linear_color)
            )

axis_args = (
  title="OBSERVED VS IPRED",
  xlabel="Individual Predicted Concentration [ng/mL]",
  ylabel="Observed Concentration [ng/mL]",
  # xticks=(0:10000:concmax, string.(Int.(round.(0:10000:concmax)))),
  # yticks=(0:10000:concmax, string.(Int.(round.(0:10000:concmax)))),
  limits = ((0, concmax),(0, concmax))
)

if log_conc
  axis_args = merge(axis_args, (xscale = Makie.pseudolog10, yscale = Makie.pseudolog10, 
                                yticks = (10 .^ (0:5), string.(10 .^ (0:5))),
                                xticks = (10 .^ (0:5), string.(10 .^ (0:5))),))
end

g2 = draw!(fig[2,1], 
           ident + obs_ipred; 
           axis = axis_args
)

# Plot 3 - Weighted Residuals vs Population Predictions
cwres_vs_pred = data(inspect_df) * 
              mapping(col_pred, col_wres) * 
              (visual(Scatter; marker = markershape, markersize = marker_size, color = markercolor, 
              strokecolor = markerstrokecolor, strokewidth = markerstrokewidth) + 
              smooth() * visual(color = smooth_color, linewidth = line_width) + 
              AlgebraOfGraphics.linear() * visual(color = linear_color)
              )

axis_args = (
  title="CWRES VS PRED",
  xlabel="Population Predicted Concentration [ng/mL]",
  ylabel="Conditional Weighted Residuals",
  #  xticks=(0:10000:concmax, string.(Int.(round.(0:10000:concmax)))),
  yticks=([-5,-4,-2, 0, 2, 4,5], ["-5","-4","-2","0","2","4","5"]),
  limits = (nothing,(-5, 5))
)

g3 = draw!(fig[1,2], 
           hlines + cwres_vs_pred; 
           axis = axis_args
)


# Plot 4 - Individual Weighted Residuals vs Individual Predictions
iwres_vs_ipred = data(inspect_df) * 
              mapping(col_ipred, col_iwres) * 
              (visual(Scatter; marker = markershape, markersize = marker_size, color = markercolor, 
              strokecolor = markerstrokecolor, strokewidth = markerstrokewidth) + 
              smooth() * visual(color = smooth_color, linewidth = line_width) + 
              AlgebraOfGraphics.linear() * visual(color = linear_color)
              )

axis_args = (
  title="IWRES VS IPRED",
  xlabel="Individual Predicted Concentration [ng/mL]",
  ylabel="Individual Weighted Residuals",
  #xticks=(0:10000:concmax, string.(Int.(round.(0:10000:concmax)))),
  yticks=([-5,-4,-2, 0, 2, 4,5], ["-5","-4","-2","0","2","4","5"]),
  limits = (nothing,(-5, 5))
)

g4 = draw!(fig[2,2], 
           hlines + iwres_vs_ipred; 
           axis = axis_args
)


# Plot 5 - Conditional Weighted Residuals vs Time 
cwres_vs_time = data(inspect_df) * 
              mapping(col_time, col_wres) * 
              (visual(Scatter; marker = markershape, markersize = marker_size, color = markercolor, 
              strokecolor = markerstrokecolor, strokewidth = markerstrokewidth) + 
              smooth() * visual(color = smooth_color, linewidth = line_width) + 
              AlgebraOfGraphics.linear() * visual(color = linear_color)
               )

g5 = draw!(fig[1,3], 
           hlines + cwres_vs_time; 
           axis = (; 
            title = "CWRES VS TIME",
            xlabel = time_label,
            ylabel="Conditional Weighted Residuals",
            #xticks = ([1*24,8*24,15*24,29*24,57*24,85*24,113*24],["1","8","15","29","57","85","113"]),  # ticks in hours, labels in days
            yticks=([-5,-4,-2, 0, 2, 4,5], ["-5","-4","-2","0","2","4","5"]),
            limits = (nothing,(-5, 5))
            )
)

# Plot 6 - Individual Weighted Residuals vs Time after first dose
iwres_vs_time = data(inspect_df) * 
              mapping(col_time, col_iwres) * 
              (visual(Scatter; marker = markershape, markersize = marker_size, color = markercolor, 
              strokecolor = markerstrokecolor, strokewidth = markerstrokewidth) + 
              smooth() * visual(color = smooth_color, linewidth = line_width) + 
              AlgebraOfGraphics.linear() * visual(color = linear_color)
              )

g5 = draw!(fig[2,3], 
           hlines + iwres_vs_time; 
           axis = (; 
            title="IWRES VS TIME",
            xlabel= time_label,
            ylabel="Individual Weighted Residuals",
            #xticks = ([1*24,8*24,15*24,29*24,57*24,85*24,113*24],["1","8","15","29","57","85","113"]), # ticks in hours, labels in days
            yticks=([-5,-4,-2, 0, 2, 4,5], ["-5","-4","-2","0","2","4","5"]),
            limits = (nothing,(-5, 5))
            )
)



# Custom Legend Creation
## Creating Legend Elements
elem_1 = [LineElement(color = smooth_color, linestyle = nothing)]
elem_2 = [LineElement(color = linear_color, linestyle = nothing)]
elem_3 = [LineElement(color = ident_color, linestyle = nothing)]
## Putting Elements Together
Legend(fig[3, 2],
    [elem_1, elem_2, elem_3],
    ["Loess", "Ordinary Least Squares (OLS)", "Identity"],
    orientation = :horizontal
    )

    return fig
end
