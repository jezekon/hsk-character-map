#!/usr/bin/env julia

"""
HSK Character Map - Complete Julia Implementation

Creates a Chinese-English graphical dictionary for Obsidian by analyzing HSK vocabulary
and generating character relationship connections.

Usage:
julia main.jl

Features:

  - Support for HSK levels 1-7
  - User selection of HSK levels to import
  - Choice between traditional and simplified characters
  - Generates Obsidian-compatible markdown files
  - Creates character relationship graph
"""
module HSKCharacterMap

using JSON

# Data structures
"""
    ChineseWord

Represents a Chinese word with all its linguistic information.
"""
struct ChineseWord
  simplified::String
  traditional::String
  pinyin::String
  pinyin_clean::String
  meaning::String
  characters::Vector{String}
end

"""
    get_user_hsk_levels() -> Vector{Int}

Prompt user to select which HSK levels to import (1-7).
Supports formats like: 1-4, 1,3,5, 6
"""
function get_user_hsk_levels()
  println("HSK Character Map - Level Selection")
  println("Available HSK levels: 1-7")
  println("Examples: 1-4 | 1,3,5 | 6")
  print("Enter HSK levels to import: ")

  input = strip(readline())
  levels = Int[]

  try
    if contains(input, "-")
      # Range format (e.g., "1-4")
      parts = split(input, "-")
      if length(parts) == 2
        start_level = parse(Int, strip(parts[1]))
        end_level = parse(Int, strip(parts[2]))
        levels = collect(start_level:end_level)
      end
    elseif contains(input, ",")
      # Comma-separated format (e.g., "1,3,5")
      parts = split(input, ",")
      levels = [parse(Int, strip(part)) for part in parts]
    else
      # Single level (e.g., "6")
      levels = [parse(Int, strip(input))]
    end

    # Validate levels are between 1-7
    levels = filter(level -> level >= 1 && level <= 7, levels)

    if isempty(levels)
      println("Error: No valid HSK levels selected. Using default: 1-4")
      levels = [1, 2, 3, 4]
    end

  catch e
    println("Error parsing input. Using default: 1-4")
    levels = [1, 2, 3, 4]
  end

  println("Selected HSK levels: $(join(levels, ", "))")
  return sort(unique(levels))
end

"""
    get_user_character_type() -> String

Prompt user to choose between traditional or simplified characters.
Returns "traditional" or "simplified".
"""
function get_user_character_type()
  println("\nCharacter Type Selection")
  println("1 - Traditional (default)")
  println("2 - Simplified")
  print("Select character type (1-2): ")

  input = strip(readline())

  if input == "2"
    println("Selected: Simplified characters")
    return "simplified"
  else
    println("Selected: Traditional characters")
    return "traditional"
  end
end

"""
    load_hsk_data(level::Int) -> Vector{Dict}

Load HSK data from JSON file for specified level (1-7).
"""
function load_hsk_data(level::Int)
  if level < 1 || level > 7
    throw(ArgumentError("HSK level must be between 1 and 7, got $level"))
  end

  filename = "data/hsk_raw/$level.json"
  if !isfile(filename)
    throw(SystemError("Data file not found: $filename"))
  end

  return JSON.parsefile(filename)
end

"""
    load_selected_hsk_data(levels::Vector{Int}) -> Vector{Dict}

Load HSK data from selected levels.
"""
function load_selected_hsk_data(levels::Vector{Int})
  all_data = Dict[]

  for level in levels
    try
      level_data = load_hsk_data(level)
      append!(all_data, level_data)
      println("Loaded $(length(level_data)) words from HSK level $level")
    catch e
      println("Warning: Could not load HSK level $level: $e")
    end
  end

  println("Total words loaded: $(length(all_data))")
  return all_data
end

"""
    clean_pinyin(pinyin::String) -> String

Remove spaces, punctuation, and tone marks from pinyin for use in filenames.
"""
function clean_pinyin(pinyin::String)
  # Remove spaces and common punctuation
  cleaned = replace(pinyin, r"[\s\.,;:!?\-()]" => "")

  # Remove tone marks - mapping accented characters to base characters
  tone_map = Dict(
    'ā' => 'a',
    'á' => 'a',
    'ǎ' => 'a',
    'à' => 'a',
    'ē' => 'e',
    'é' => 'e',
    'ě' => 'e',
    'è' => 'e',
    'ī' => 'i',
    'í' => 'i',
    'ǐ' => 'i',
    'ì' => 'i',
    'ō' => 'o',
    'ó' => 'o',
    'ǒ' => 'o',
    'ò' => 'o',
    'ū' => 'u',
    'ú' => 'u',
    'ǔ' => 'u',
    'ù' => 'u',
    'ü' => 'v',
    'ǘ' => 'v',
    'ǚ' => 'v',
    'ǜ' => 'v',
    'ǖ' => 'v'
  )

  result = ""
  for char in cleaned
    result *= get(tone_map, char, char)
  end

  return lowercase(result)
end

"""
    split_into_characters(word::String) -> Vector{String}

Split a Chinese word into individual characters.
"""
function split_into_characters(word::String)
  return [string(char) for char in word if !isspace(char)]
end

"""
    parse_hsk_word(word_data::Dict, character_type::String) -> Union{ChineseWord, Nothing}

Parse a single HSK word entry from JSON data into a ChineseWord struct.
"""
function parse_hsk_word(word_data::Dict, character_type::String)
  try
    simplified = word_data["simplified"]

    # Get the first form (there might be multiple)
    if !haskey(word_data, "forms") || isempty(word_data["forms"])
      return nothing
    end

    first_form = word_data["forms"][1]
    traditional = first_form["traditional"]
    pinyin = first_form["transcriptions"]["pinyin"]

    # Get first meaning
    meanings = first_form["meanings"]
    if isempty(meanings)
      return nothing
    end
    meaning = meanings[1]

    # Create clean pinyin for filename
    pinyin_clean = clean_pinyin(pinyin)

    # Choose character set based on user preference
    main_characters = character_type == "simplified" ? simplified : traditional

    # Split into individual characters
    characters = split_into_characters(main_characters)

    return ChineseWord(simplified, traditional, pinyin, pinyin_clean, meaning, characters)

  catch e
    return nothing
  end
end

"""
    create_filename(word::ChineseWord, character_type::String) -> String

Create filename following the convention: [Characters] ([Pinyin with tones]), [Pinyin clean].md
"""
function create_filename(word::ChineseWord, character_type::String)
  main_chars = character_type == "simplified" ? word.simplified : word.traditional
  return "$(main_chars) ($(word.pinyin)), $(word.pinyin_clean).md"
end

"""
    find_character_connections(target_word::ChineseWord, all_words::Vector{ChineseWord}, character_type::String) -> Vector{String}

Find all characters from target_word that exist as standalone words in the dictionary.
"""
function find_character_connections(
  target_word::ChineseWord,
  all_words::Vector{ChineseWord},
  character_type::String
)
  connections = String[]

  # Create a lookup dictionary for quick searching
  word_lookup = Dict{String, ChineseWord}()
  for word in all_words
    lookup_chars = character_type == "simplified" ? word.simplified : word.traditional
    word_lookup[lookup_chars] = word
  end

  # Check each character of the target word
  for char in target_word.characters
    if haskey(word_lookup, char)
      connected_word = word_lookup[char]
      filename = create_filename(connected_word, character_type)
      push!(connections, filename)
    end
  end

  return connections
end

"""
    create_markdown_content(word::ChineseWord, connections::Vector{String}, character_type::String) -> String

Create markdown content for a word file.
"""
function create_markdown_content(
  word::ChineseWord,
  connections::Vector{String},
  character_type::String
)
  main_chars = character_type == "simplified" ? word.simplified : word.traditional
  content = "$(main_chars)\n$(word.meaning)"

  # Add connections if any exist
  if !isempty(connections)
    content *= "\n\n## Character Components\n"
    for connection in connections
      # Extract the character from the filename for display
      char_part = split(connection, " (")[1]
      content *= "- [[$char_part]]\n"
    end
  end

  return content
end

"""
    create_obsidian_vault(words::Vector{ChineseWord}, character_type::String, output_dir::String = "ObsidianVault") -> Int

Create Obsidian vault with markdown files for all words and their character connections.
"""
function create_obsidian_vault(
  words::Vector{ChineseWord},
  character_type::String,
  output_dir::String = "ObsidianVault"
)
  # Create output directory
  if !isdir(output_dir)
    mkdir(output_dir)
    println("Created directory: $output_dir")
  end

  println("Generating markdown files...")
  files_created = 0

  for word in words
    # Find character connections
    connections = find_character_connections(word, words, character_type)

    # Create markdown content
    content = create_markdown_content(word, connections, character_type)

    # Create filename
    filename = create_filename(word, character_type)
    filepath = joinpath(output_dir, filename)

    # Write file
    try
      open(filepath, "w") do file
        write(file, content)
      end
      files_created += 1

      # Show progress every 100 files
      if files_created % 100 == 0
        println("Created $files_created files...")
      end
    catch e
      println("Warning: Could not create file $filename: $e")
    end
  end

  println("Created $files_created markdown files in $output_dir")
  return files_created
end

"""
    process_hsk_data(levels::Vector{Int}, character_type::String) -> Vector{ChineseWord}

Main function to load and process selected HSK data.
"""
function process_hsk_data(levels::Vector{Int}, character_type::String)
  println("Starting HSK Character Map generation...")

  # Load selected HSK data
  raw_data = load_selected_hsk_data(levels)

  if isempty(raw_data)
    throw(ErrorException("No HSK data could be loaded. Please check data files."))
  end

  # Parse into ChineseWord structs
  println("Parsing word data...")
  words = ChineseWord[]
  skipped = 0

  for word_data in raw_data
    parsed_word = parse_hsk_word(word_data, character_type)
    if parsed_word !== nothing
      push!(words, parsed_word)
    else
      skipped += 1
    end
  end

  println("Successfully parsed $(length(words)) words")
  if skipped > 0
    println("Skipped $skipped words due to parsing errors")
  end

  return words
end

"""
    main()

Main entry point for the HSK Character Map generation.
"""
function main()
  println("HSK Character Map - Julia Implementation")
  println("=======================================")

  try
    # Get user preferences
    levels = get_user_hsk_levels()
    character_type = get_user_character_type()

    # Process HSK data
    words = process_hsk_data(levels, character_type)

    if isempty(words)
      println("Error: No words were successfully processed")
      println("Please check that HSK data files exist in 'data/' directory")
      return
    end

    # Create Obsidian vault
    files_created = create_obsidian_vault(words, character_type)

    println("\nProcessing complete!")
    println("Obsidian vault created with $files_created files")
    println("Character type: $(character_type)")
    println("HSK levels: $(join(levels, ", "))")
    println("\nNext steps:")
    println("1. Open Obsidian")
    println("2. Click 'Open folder as vault'")
    println("3. Select the 'ObsidianVault' directory")
    println("4. Open Graph View to see character connections")

  catch e
    println("Error during processing: $e")
    println("Please check that the data files exist in the 'data/' directory")
    println("Expected files: data/hsk_raw/1.json, data/hsk_raw/2.json, etc.")
  end
end

# Run main function if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
  main()
end

end # module HSKCharacterMap
