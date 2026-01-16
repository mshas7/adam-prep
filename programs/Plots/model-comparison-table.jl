###---------------------------------------------------------------------------
### Utility Function to Generate Model Comparison Table
###---------------------------------------------------------------------------

# Definitions 
#---------------------------------------------------------------------------

# Function: compare_model_metrics_table(fits)
#
# fits: list of inspect object
# infers: list of infer object
# notes: list of notes for each model


# Create Function
#---------------------------------------------------------------------------

function model_comparison_table(fits::NamedTuple, infers::NamedTuple,  notes::NamedTuple)
    # Extract model names and fits as strings
    model_names = string.(collect(keys(fits)))
    fit_list = collect(values(fits))
    infer_list = collect(values(infers))
    notes_list = collect(values(notes))

    # Helper to get condition number safely and note if it fails
    function safe_cond(infer)
        try
           # inf = infer(fit; rethrow_error=false)
            return cond(infer), ""
        catch
            return "NA", "Covariance step failed"
        end
    end

    # Helper to convert minimization status
    function minimization_status(val)
        if val === true
            return "Successful"
        elseif val === false
            return "Fail"
        else
            return "NA"
        end
    end

    # Gather metrics for each model
    successful_raw = [metrics_table(fit)[metrics_table(fit).Metric .== "Successful", :Value][1] for fit in fit_list]
    cond = [safe_cond(infer) for infer in infer_list]
    CNs = [x[1] for x in cond]
    Descriptions = [get(fit.model.metadata, :desc, "") for fit in fit_list]

    metrics = DataFrame(
        Model = model_names,
        Description = Descriptions,
        Minimization = [minimization_status(val) for val in successful_raw],
        minus2LL = [-2 * loglikelihood(fit) for fit in fit_list],
        AIC = [aic(fit) for fit in fit_list],
        BIC = [bic(fit) for fit in fit_list],
    )

    # Calculate differences with the first model
    metrics."Δ-2LL" = metrics.minus2LL .- metrics.minus2LL[1]
    metrics."ΔAIC" = metrics.AIC .- metrics.AIC[1]
    metrics."ΔBIC" = metrics.BIC .- metrics.BIC[1]


    # Add CN and Notes as the last two columns
    metrics.CN = CNs
    metrics.Notes = notes_list

    # Prepare for SummaryTables.Table
    mat = Matrix(metrics)
    header = ["Model", "Description", "Minimization", "-2LL", "AIC", "BIC", "Δ-2LL", "ΔAIC", "ΔBIC", "CN", "Notes"]
    header_cells = map(x -> Cell(x; halign=:left, bold=true), header)
    header_row = reshape(header_cells, 1, :)

    # Format the rest of the table cells
    rest = Cell.(mat; halign=:left)

    # Combine headers and data into a table
    metricstbl = Table(
        vcat(header_row, rest),
        footnotes=[
            "Abbreviations: AIC = Akaike Information Criterion; BIC = Bayesian Information Criterion; -2LL = -2 Log Likelihood; CN = Condition Number.",
            "Condition Number (CN) is reported as NA if inference failed.",
            "Differences (ΔBIC, ΔAIC, Δ-2LL) are calculated with respect to model \"$(metrics.Model[1])\".",
            prog_ref])


    return metricstbl
end
