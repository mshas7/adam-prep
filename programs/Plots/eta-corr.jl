###---------------------------------------------------------------------------
### Utility Function to Generate ETA Correlations Plot
###---------------------------------------------------------------------------

# Definitions 
#---------------------------------------------------------------------------

# Function: eta_corr(inspect_obj)
#
# inspect_obj: inspect object


# Create Function
#---------------------------------------------------------------------------

function eta_corr(inspect_obj)
    # Create a DataFrame retaining EBE information based on the inspect object
    ebes = @chain DataFrame(inspect_obj) begin
        # Select only columns that contain η
        select(r"^η")
        # Exclude any missing values
        dropmissing
    end

    # Construct a figure object
    p_etacorr = Figure()
    
    # Add a title label at the top
    Label(p_etacorr[0, 1], 
         "Random-Effects Correlation Plot", 
         fontsize = 18, 
         tellheight = true, # This allows the legend to tell or influence the overall height of the layout
         tellwidth = false)  # The legend won’t affect the figure’s width.

    # Construct the pairwise plot
    pairplot(
        p_etacorr[1, 1],
        # Specify the input DataFrame
        ebes => (
            # Specify the elements that should be presented on the off-diagonals
            # Scatterplot with correlation and trendline
            PairPlots.Scatter(
                marker = '∘',
                markersize = 24,
                alpha = 0.5,
                color = ColorSchemes.tab10.colors[1],
            ),
            PairPlots.TrendLine(color = :red),
            PairPlots.PearsonCorrelation(fontsize = 14, color = :red),

            # Specify elements that should be presented on the diagonals
            # Histogram
            PairPlots.MarginHist(color = ColorSchemes.tab10.colors[1]),
        ),
        fullgrid = false
    )
    # Print the plot
    return p_etacorr
end

