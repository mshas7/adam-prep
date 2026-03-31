function stats_cat(x)
    nonmissing = skipmissing(x)
    total = length(collect(nonmissing))
    missings = sum(ismissing, x)

    categories = isnothing(levels(x)) ? unique(collect(nonmissing)) : levels(x)

    results = [
        count(==(cat), nonmissing) == 0 ?
        "-" => string(cat) :
        string(count(==(cat), nonmissing), " (", round(100 * count(==(cat), nonmissing) / total, sigdigits=2), "%)") => string(cat)
        for cat in categories
    ]

    # Optional - include missing
    # push!(results, (string(missings) => "Missing"))

    return Tuple(results)
end

# Table Helpers
nmissing(v) = string(Int(count(ismissing, v)))

nunique(x) = length(unique(x))

nunique_with_excl(x, exclf) = (length(unique(x[exclf.== 0])))
