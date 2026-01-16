#Convert StringN type columns to String
function coerce_string_columns!(df::AbstractDataFrame) 
    for c in names(df) 
        col = df[!, c] # convert if every non-missing entry is string-like 
        if all(x -> ismissing(x) || x isa AbstractString, col) 
            df[!, c] = [ismissing(x) ? missing : String(x) for x in col] 
        end 
    end 
    return df 
end