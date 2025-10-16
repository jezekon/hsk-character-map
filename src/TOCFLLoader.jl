# src/TOCFLLoader.jl
#
# TOCFL vocabulary loader - loads vocabulary from Excel file
# Supports both 3-column and 4-column formats

module TOCFLLoader

using XLSX

export load_tocfl_data, get_user_tocfl_levels

# TOCFL level definitions
const TOCFL_LEVELS = [
    ("準備級一級(Novice 1)", "Novice1", "N1"),
    ("準備級二級(Novice 2)", "Novice2", "N2"),
    ("入門級(Level 1)", "Level1", "L1"),
    ("基礎級(Level 2)", "Level2", "L2"),
    ("進階級(Level 3)", "Level3", "L3"),
    ("高階級(Level 4)", "Level4", "L4"),
    ("流利級(Level 5)", "Level5", "L5"),
]

"""
    get_user_tocfl_levels() -> Vector{Int}

Prompt user to select which TOCFL levels to import (1-7).
"""
function get_user_tocfl_levels()
    println("\nTOCFL Level Selection")
    println("Available TOCFL levels:")
    for (i, (sheet_name, display_name, code)) in enumerate(TOCFL_LEVELS)
        println("  $i. $display_name")
    end
    println("\nExamples: 1-4 | 1,3,5 | 7")
    print("Enter TOCFL levels to import: ")

    input = strip(readline())
    indices = Int[]

    try
        if contains(input, "-")
            parts = split(input, "-")
            if length(parts) == 2
                start_idx = parse(Int, strip(parts[1]))
                end_idx = parse(Int, strip(parts[2]))
                indices = collect(start_idx:end_idx)
            end
        elseif contains(input, ",")
            parts = split(input, ",")
            indices = [parse(Int, strip(part)) for part in parts]
        else
            indices = [parse(Int, strip(input))]
        end

        # Validate indices
        indices = filter(i -> i >= 1 && i <= length(TOCFL_LEVELS), indices)

        if isempty(indices)
            println("No valid levels selected. Using default: 1-4")
            indices = [1, 2, 3, 4]
        end

    catch e
        println("Error parsing input. Using default: 1-4")
        indices = [1, 2, 3, 4]
    end

    selected = [TOCFL_LEVELS[i][2] for i in sort(unique(indices))]
    println("Selected TOCFL levels: $(join(selected, ", "))")
    return sort(unique(indices))
end

"""
    detect_format(sheet::XLSX.Worksheet) -> Symbol

Detect if sheet has 3 or 4 columns.
Returns :four_column or :three_column
"""
function detect_format(sheet::XLSX.Worksheet)
    # Check first row for headers
    first_row_vals = []
    for col = 1:5
        try
            val = sheet[1, col]
            if !isnothing(val) && !isempty(string(val))
                push!(first_row_vals, string(val))
            end
        catch
            break
        end
    end

    # Look for "Context" or "任務領域" in headers
    has_context = any(h -> occursin(r"Context|任務領域"i, h), first_row_vals)

    return has_context || length(first_row_vals) >= 4 ? :four_column : :three_column
end

"""
    parse_row_four_column(sheet, row_num) -> Union{Dict, Nothing}

Parse row with format: Context | Vocabulary | Pinyin | Parts of Speech
"""
function parse_row_four_column(sheet, row_num)
    try
        context = sheet[row_num, 1]
        vocab = sheet[row_num, 2]
        pinyin = sheet[row_num, 3]
        pos = sheet[row_num, 4]

        # Skip if vocabulary is empty
        if isnothing(vocab) || isempty(strip(string(vocab)))
            return nothing
        end

        return Dict(
            "vocabulary" => strip(string(vocab)),
            "pinyin" => strip(string(pinyin)),
            "parts_of_speech" => strip(string(pos)),
            "context" => isnothing(context) ? nothing : strip(string(context)),
        )
    catch
        return nothing
    end
end

"""
    parse_row_three_column(sheet, row_num) -> Union{Dict, Nothing}

Parse row with format: Vocabulary | Pinyin | Parts of Speech
"""
function parse_row_three_column(sheet, row_num)
    try
        vocab = sheet[row_num, 1]
        pinyin = sheet[row_num, 2]
        pos = sheet[row_num, 3]

        # Skip if vocabulary is empty
        if isnothing(vocab) || isempty(strip(string(vocab)))
            return nothing
        end

        return Dict(
            "vocabulary" => strip(string(vocab)),
            "pinyin" => strip(string(pinyin)),
            "parts_of_speech" => strip(string(pos)),
            "context" => nothing,
        )
    catch
        return nothing
    end
end

"""
    parse_sheet(sheet::XLSX.Worksheet, level_name::String, level_code::String) -> Vector{Dict}

Parse a single TOCFL sheet and return array of word dictionaries.
"""
function parse_sheet(sheet::XLSX.Worksheet, level_name::String, level_code::String)
    words = []

    # Detect format
    format = detect_format(sheet)

    # Get dimensions
    rows = XLSX.get_dimension(sheet).stop.row_number

    # Parse each row (skip header row 1)
    for row_num = 2:rows
        word_data = if format == :four_column
            parse_row_four_column(sheet, row_num)
        else
            parse_row_three_column(sheet, row_num)
        end

        if !isnothing(word_data)
            word_data["level"] = level_code
            word_data["level_name"] = level_name
            push!(words, word_data)
        end
    end

    return words
end

"""
    load_tocfl_data(excel_path::String, level_indices::Vector{Int}) -> Vector{Dict}

Load TOCFL data from Excel file for selected levels.
Returns array of word dictionaries compatible with HSK format.
"""
function load_tocfl_data(excel_path::String, level_indices::Vector{Int})
    if !isfile(excel_path)
        throw(SystemError("TOCFL Excel file not found: $excel_path"))
    end

    all_words = []

    try
        xf = XLSX.readxlsx(excel_path)

        for idx in level_indices
            if idx < 1 || idx > length(TOCFL_LEVELS)
                println("Warning: Invalid level index $idx, skipping...")
                continue
            end

            sheet_name, display_name, level_code = TOCFL_LEVELS[idx]

            # Check if sheet exists
            if !XLSX.hassheet(xf, sheet_name)
                println("Warning: Sheet '$sheet_name' not found, skipping...")
                continue
            end

            println("Loading TOCFL $display_name...")
            sheet = xf[sheet_name]
            words = parse_sheet(sheet, display_name, level_code)
            append!(all_words, words)
            println("  Loaded $(length(words)) words")
        end

        XLSX.close(xf)

    catch e
        println("Error loading TOCFL Excel: $e")
        rethrow(e)
    end

    println("Total TOCFL words: $(length(all_words))")
    return all_words
end

end # module TOCFLLoader
