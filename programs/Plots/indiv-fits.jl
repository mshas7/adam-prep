###---------------------------------------------------------------------------
### Utility Function to Generate Individual Fits
###---------------------------------------------------------------------------

# Definitions 
#---------------------------------------------------------------------------

# Function: indiv_fits(pred_obj, log_conc)
#
# pred_obj: predict object
# log_conc = plot concentrations in log scale: true or false
# ids = subject ids to be plotted


# Create Function
#---------------------------------------------------------------------------

function indiv_fits(pred_obj, log_conc, ids)

  axis_args = (
      xlabel = "Time [h]",
      ylabel = "Observed/Predicted Concentration [ng/mL]",
     # xticks = 0:12:168,
     #xticklabelsize = 12, 
     #yticklabelsize = 8 
    ) 

    if log_conc 
      axis_args = merge(axis_args, (xscale = identity, yscale = Makie.pseudolog10, 
                                    yticks = (10 .^ (0:5), string.(10 .^ (0:5))),))
    end

  fig = subject_fits(
    pred_obj,
    observations = [:DV],
    ids = unique(ids),
    axis = axis_args,
    separate = true,  # Get one plot per id
    paginate = true, # Generate a vector of plots 
    limit = 9, # Number of plots per vector
    facet = (
          linkxaxes = false, # Separate x axes for each individual
          linkyaxes = false  # separate y axes for each individual
      ),
    labels=(;
      data = "Observed",
      ipred = "Individual Predicted",
      pred = "Population Predicted" ),
    markercolor=:navy,
    ipred_color=:green,
    pred_color=:red,
    include_legend = true,
    figurelegend = (
        position = :b,  # Places the legend at the bottom
        framevisible = false,  # Hides the frame (border) around the legend box
        orientation = :vertical, # Arranges the legend items vertically 
        tellheight = true, # This allows the legend to tell or influence the overall height of the layout
        tellwidth = false,  # The legend won’t affect the figure’s width.
        nbanks = 3  # Controls the number of columns (or banks) of legend items 
    )
    )

    return fig
end


