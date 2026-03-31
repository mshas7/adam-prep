# v1.0.0
module ParameterTables

using SummaryTables
using DataFrames
using Typst_jll
using TableMetadataTools
# using Pumas
# using PumasUtilities

import WriteDocx as W


export parameter_table, infer_table, table_to_pdf, table_to_docx

function table_to_docx(name::AbstractString, directory, tabl)
    doc = W.Document(W.Body([W.Section([SummaryTables.to_docx(tabl)])]))
    W.save(joinpath(directory, name * ".docx"), doc)
end


# render latex in a temp directory
function table_to_pdf(name::AbstractString, directory, table)
    mktempdir() do dir
        typfile = joinpath(dir, "example.typ")

        open(typfile, "w") do io
            # print the table as latex code
            println(io, """#set page(width: auto, height: auto)""")
            show(io, MIME"text/typst"(), table)
        end

        # render the tex file to pdf
        run(`$(Typst_jll.typst()) compile $typfile`)

        cp(joinpath(dir, "example.pdf"), joinpath(directory, name * ".pdf"); force = true)
    end
end

function _infer_footnote(inf)
    if inf.vcov isa Pumas.Bootstraps
        strat_string = if inf.vcov.stratify_by isa Nothing
            "without stratified resampling"
        else
            "with stratified resampling based on $(inf.stratify_by)"
        end
        " based on bootstrap $(strat_string) with $(length(inf.vcov.fits)) replications ($(length(filter(x->x isa Pumas.FittedPumasModel, inf.vcov.fits))) successful fits)."
    elseif inf.vcov isa Pumas.CovarianceEstimate
        " based on the asymptotic variance-covariance matrix. "
    else
        throw(ErrorException("Simulated inference not supported"))
    end
end
function _unpack_entries_omega(nt::NamedTuple)
    mapping = []
    subscript(s) = join(Char(0x2080) + Int(c) for c in s)
    function name(k, v::AbstractVector)
        for (i, item) in enumerate(v)
            push!(mapping, string(k, subscript(i), ",", subscript(i)) => item)
        end
    end
    name(k, v::Number) = push!(mapping, "$k" => v)

    for (k, v) in pairs(nt)
        name(k, v)
    end
    return mapping
end
function omega_to_eta(param, eta_omega, eta_shrinkage)
    # check if the name of the omega exists in names (without subscripts)
    # then it's a univariate random effect
    omega_split = split(param, ['₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉'])
    omega_clean = first(omega_split)
    # Find the direct match
    name_dx = findfirst(x -> x.value == eta_omega[omega_clean], keys(eta_shrinkage))
    if name_dx !== nothing
        return eta_shrinkage[name_dx]
    else
        eta_num = last(split(name, omega_clean))
        _idx = findfirst(
            x -> x.value == eta_omega[omega_clean] * eta_num * "," * eta_num,
            __names,
        )
        _shrinkage[_idx] = Cell(string(round(last(eta); digits = 3)))
    end
end
using DataFramesMeta

CI_label(fpmi) = string(
    "Confidence interval at  ",
    round(100 * fpmi.level, digits = 1),
    "% confidence level ",
)

cond_info(
    fpmi::Pumas.FittedPumasModelInference{<:Any,<:Pumas.CovarianceEstimate,<:Any};
    correlation,
) = cond(fpmi; correlation)
cond_info(
    fpmi::Pumas.FittedPumasModelInference{<:Any,<:Pumas.Bootstraps,<:Any};
    correlation,
) = nothing
cond_info(
    fpmi::Pumas.FittedPumasModelInference{<:Any,<:Pumas.SimulatedInference,<:Any};
    correlation,
) = nothing
function parameter_table(fpmi; eta_omega, latex = false, correlation_condition = true)

    coff = coeftable(fpmi)
    descriptions = PumasReports._markdown_descriptions(fpmi.fpm; latex = latex)
    descriptions = [get(descriptions, nth, "") for nth = 1:nrow(coff)]
    any(s -> !isempty(s), descriptions) &&
        insertcols!(coff, 2, :description => descriptions)

    # Set constant true to missing not NaN
    @rtransform! coff :se = :constant ? missing : :se
    @rtransform! coff :relative_se = :constant ? missing : :relative_se
    @rtransform! coff :ci_lower = :constant ? missing : :ci_lower
    @rtransform! coff :ci_upper = :constant ? missing : :ci_upper

    coff.relative_se .*= 100

    # does this fail if none are present? shouldn't it just be an empty nt?
    trydo = (f, arg) -> try
        f(arg)
    catch
        (FAILED = NaN,)
    end

    # Munge shrinkage
    ηmap = trydo(ηshrinkage, fpmi.fpm)
    replace(keys(ηmap), eta_omega...)
    ηmap =
        _unpack_entries_omega(NamedTuple{replace(keys(ηmap), eta_omega...)}(values(ηmap)))
    ηdf = rename!(DataFrame(ηmap, ["parameter", "shrinkage"]))
    ηdf.shrinkage .*= 100

    # Add Shrinkage
    df_sh1 = leftjoin(coff, ηdf; on = :parameter, order = :left)

    colmetadata!(df_sh1, :parameter, "label", "Parameter", style = :note)
    colmetadata!(df_sh1, :description, "label", "Description", style = :note)
    colmetadata!(df_sh1, :constant, "label", "Constant", style = :note)
    colmetadata!(df_sh1, :estimate, "label", "Estimate", style = :note)
    colmetadata!(df_sh1, :se, "label", "SE", style = :note)
    colmetadata!(df_sh1, :relative_se, "label", "% Relative SE", style = :note)
    colmetadata!(df_sh1, :ci_lower, "label", "CI Lower", style = :note)
    colmetadata!(df_sh1, :ci_upper, "label", "CI Upper", style = :note)
    colmetadata!(df_sh1, :shrinkage, "label", "% η-shrinkage", style = :note)
    _footnotes = []
    metadata!(df_sh1, "footnotes", _footnotes; style = :note)
    push!(_footnotes, CI_label(fpmi) * " " * _infer_footnote(fpmi))
    cond_fpmi = cond_info(fpmi; correlation = correlation_condition)
    if !isnothing(cond_fpmi)
        push!(
            _footnotes,
            "Condition number of $(["covariance", "correlation"][correlation_condition+1]) matrix: $cond_fpmi",
        )
    end
    push!(_footnotes, "Log-likelihood: $(loglikelihood(fpmi.fpm))")
    epsshrinkage = trydo(ϵshrinkage, fpmi.fpm)
    if !isempty(epsshrinkage)
        push!(_footnotes, string("ϵ-shrinkage (%): ", map(x -> x * 100, epsshrinkage)))
    end
    return df_sh1
end

function infer_table(
    fpmi;
    round_digits = 3,
    round_mode = :auto,
    eta_omega = nothing,
    include_standarderrors = false,
    latex = false,
    caller_path,
    path,
)
    coff = parameter_table(fpmi; eta_omega, latex)
    for col in (:se, :relative_se, :ci_lower, :ci_upper)
        coff[!, col] = coalesce.(coff[!, col], "fixed")
    end
    __names = @. Cell(coff.parameter; halign = :left)
    _description = @. Cell(coff.description; halign = :left)
    _constant = @. Cell(coff.constant; halign = :center)
    _para = @. Cell(coff.estimate)
    _shrinkage = @. Cell(coff.shrinkage)
    _rse = @. Cell(coff.relative_se)
    _se = @. Cell(coff.se)
    _ci_low = @. Cell(coff.ci_lower)
    _ci_high = @. Cell(coff.ci_upper)
    #    rename!(par_tab, labels(par_tab))

    if !include_standarderrors
        rest = [__names _description _para _rse _ci_low _ci_high _shrinkage]
        select!(coff, Not(:se))
    else
        rest = [__names _description _para _se _rse _ci_low _ci_high _shrinkage]
    end
    select!(coff, Not(:constant))
    rename!(coff, labels(coff))
    header_row = permutedims(names(coff))

    header = @. Cell(header_row)
    tab = Table(
        [header; rest];
        header = 1,
        footnotes = [
            metadata(coff, "footnotes")...,
            "Program Source: $(caller_path)",
            "Source: $(path)",
        ],
        round_digits,
        round_mode,
        postprocess = [ReplaceMissing(; with = "-")],
    )

    tab
end
end
