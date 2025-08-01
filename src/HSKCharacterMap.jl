#!/usr/bin/env julia

"""
HSK Character Map - Enhanced Julia Implementation

Creates a Chinese-English graphical dictionary for Obsidian by analyzing HSK vocabulary
and generating character relationship connections with complete meaning aggregation.

Enhanced with proper link management to avoid duplicate files and broken links.

Usage:
julia main.jl

Features:

  - Support for HSK levels 1-7
  - User selection of HSK levels to import
  - Choice between traditional and simplified characters
  - Generates Obsidian-compatible markdown files with HSK level tags
  - Aggregates ALL meanings for each character from all word contexts
  - Creates character relationship graph
  - **NEW**: Proper standalone character detection to avoid broken links
"""
module HSKCharacterMap

using JSON

# Data structures
"""
    ChineseWord

Represents a Chinese word with all its linguistic information including HSK level.
"""
struct ChineseWord
  simplified::String
  traditional::String
  pinyin::String
  pinyin_clean::String
  meaning::String
  all_meanings::Vector{String}  # Store all meanings for this word
  characters::Vector{String}
  hsk_level::Int
end

"""
    CharacterMeanings

Aggregates all meanings for a specific character across all words.
"""
struct CharacterMeanings
  character::String
  all_meanings::Vector{String}
  hsk_levels::Vector{Int}
end

# **NEW**: Enhanced character info for proper link management
"""
    CharacterInfo

Enhanced character information including standalone word detection.
"""
struct CharacterInfo
  character::String
  is_standalone_word::Bool
  filename::String
  meanings::CharacterMeanings
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

Load HSK data for a specific level from JSON file.
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
    load_selected_hsk_data(levels::Vector{Int}) -> Vector{Tuple{Dict, Int}}

Load and combine HSK data for selected levels with level tracking.
"""
function load_selected_hsk_data(levels::Vector{Int})
  all_data = Tuple{Dict, Int}[]

  for level in levels
    try
      level_data = load_hsk_data(level)
      level_tuples = [(word_data, level) for word_data in level_data]
      append!(all_data, level_tuples)
      println("Loaded HSK level $level: $(length(level_data)) words")
    catch e
      println("Warning: Could not load HSK level $level: $e")
    end
  end

  println("Total: $(length(all_data)) words")
  return all_data
end

"""
    clean_pinyin(pinyin::String) -> String

Remove tone marks and special characters from pinyin for use in filenames.
"""
function clean_pinyin(pinyin::String)
  # Remove punctuation and spaces
  cleaned = replace(pinyin, r"[\s\.,;:!?\-()]" => "")

  # Define tone mark to base character mapping
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
    parse_hsk_word(word_data::Dict, character_type::String, hsk_level::Int) -> Union{ChineseWord, Nothing}

Parse a single HSK word entry from JSON data into a ChineseWord struct with HSK level.
Now extracts ALL meanings from the word data.
"""
function parse_hsk_word(word_data::Dict, character_type::String, hsk_level::Int)
  try
    simplified = word_data["simplified"]

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

    # Store all meanings and use first one as primary
    all_meanings = copy(meanings)
    primary_meaning = meanings[1]

    pinyin_clean = clean_pinyin(pinyin)
    main_characters = character_type == "simplified" ? simplified : traditional
    characters = split_into_characters(main_characters)

    return ChineseWord(
      simplified,
      traditional,
      pinyin,
      pinyin_clean,
      primary_meaning,
      all_meanings,
      characters,
      hsk_level
    )

  catch e
    return nothing
  end
end

"""
    build_character_meanings_map(words::Vector{ChineseWord}, character_type::String) -> Dict{String, CharacterMeanings}

Build a comprehensive mapping of each character to all its meanings across all words.
This aggregates meanings from different words that contain the same character.
"""
function build_character_meanings_map(words::Vector{ChineseWord}, character_type::String)
  char_meanings_map = Dict{String, CharacterMeanings}()

  println("Building character meanings map...")

  for word in words
    # Use the appropriate character set
    word_chars = character_type == "simplified" ? word.simplified : word.traditional

    # Process each character in this word
    for char in split_into_characters(word_chars)
      if haskey(char_meanings_map, char)
        # Character already exists, merge meanings and levels
        existing = char_meanings_map[char]
        new_meanings = union(existing.all_meanings, word.all_meanings)
        new_levels = union(existing.hsk_levels, [word.hsk_level])

        char_meanings_map[char] =
          CharacterMeanings(char, collect(new_meanings), sort(collect(new_levels)))
      else
        # First time seeing this character
        char_meanings_map[char] =
          CharacterMeanings(char, copy(word.all_meanings), [word.hsk_level])
      end
    end
  end

  println("Mapped meanings for $(length(char_meanings_map)) unique characters")
  return char_meanings_map
end

# **NEW**: Enhanced character info mapping for proper link management
"""
    build_character_info_map(words::Vector{ChineseWord}, character_type::String) -> Dict{String, CharacterInfo}

Build comprehensive character information map with proper standalone word detection.
This prevents duplicate files and broken links.
"""
function build_character_info_map(words::Vector{ChineseWord}, character_type::String)
  char_info_map = Dict{String, CharacterInfo}()

  # Build character meanings map first (reuse existing function)
  char_meanings_map = build_character_meanings_map(words, character_type)

  # Create word lookup for fast standalone character detection
  word_lookup = Set{String}()
  word_to_word_map = Dict{String, ChineseWord}()

  for word in words
    lookup_chars = character_type == "simplified" ? word.simplified : word.traditional
    push!(word_lookup, lookup_chars)
    word_to_word_map[lookup_chars] = word
  end

  # Process each character and determine if it's a standalone word
  for (char, char_meanings) in char_meanings_map
    is_standalone = char in word_lookup

    filename = if is_standalone
      standalone_word = word_to_word_map[char]
      create_filename(standalone_word, character_type)
    else
      "$char.md"  # Simple filename for non-standalone characters
    end

    char_info_map[char] = CharacterInfo(char, is_standalone, filename, char_meanings)
  end

  standalone_count = count(info -> info.is_standalone_word, values(char_info_map))
  println("Mapped $(length(char_info_map)) characters ($standalone_count standalone)")

  return char_info_map
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

# **NEW**: Enhanced link generation for proper character references
"""
    get_character_link(char::String, char_info_map::Dict{String, CharacterInfo}) -> String

Get the proper Obsidian link for a character, using the correct filename.
"""
function get_character_link(char::String, char_info_map::Dict{String, CharacterInfo})
  if haskey(char_info_map, char)
    char_info = char_info_map[char]
    if char_info.is_standalone_word
      # Link to the full word file (without .md extension)
      link_name = replace(char_info.filename, ".md" => "")
      return "[[$(link_name)]]"
    else
      # Link to simple character file
      return "[[$(char)]]"
    end
  else
    # Fallback - simple character link
    return "[[$(char)]]"
  end
end

"""
    create_markdown_content(word::ChineseWord, connections::Vector{String}, character_type::String, char_meanings_map::Dict{String, CharacterMeanings}) -> String

Create markdown content for a word file with HSK level tag and enhanced meanings.
"""
function create_markdown_content(
  word::ChineseWord,
  connections::Vector{String},
  character_type::String,
  char_meanings_map::Dict{String, CharacterMeanings}
)
  main_chars = character_type == "simplified" ? word.simplified : word.traditional

  # First line: HSK level tag
  hsk_tag = "#hsk$(word.hsk_level)"
  content = "$(hsk_tag)\n"

  # Second line: Traditional Chinese characters
  # content *= "$(word.traditional)\n"

  # Third line: Primary meaning
  content *= "$(word.meaning)"

  # If this is a single character, show all its aggregated meanings
  if length(word.characters) == 1 && haskey(char_meanings_map, main_chars)
    char_meanings = char_meanings_map[main_chars]
    if length(char_meanings.all_meanings) > 1
      content *= "\n\n### Meanings:\n"
      for meaning in char_meanings.all_meanings
        content *= "$meaning\n"
      end
    end
  end

  # Add word meanings if it's a multi-character word with multiple meanings
  if length(word.characters) > 1 && length(word.all_meanings) > 1
    content *= "\n\n### Word Meanings:\n"
    for meaning in word.all_meanings
      content *= "$meaning\n"
    end
  end

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

# **NEW**: Enhanced markdown content creation with proper character links
"""
    create_enhanced_markdown_content(word::ChineseWord, char_info_map::Dict{String, CharacterInfo}, character_type::String) -> String

Create markdown content with enhanced character links to avoid broken references.
"""
function create_enhanced_markdown_content(
  word::ChineseWord,
  char_info_map::Dict{String, CharacterInfo},
  character_type::String
)
  # HSK level tag
  content = "#hsk$(word.hsk_level)\n"

  # Primary meaning
  content *= "$(word.meaning)"

  # Add all meanings if multiple exist
  if length(word.all_meanings) > 1
    content *= "\n\n### All meanings:\n"
    for meaning in word.all_meanings
      content *= "- $meaning\n"
    end
  end

  # Add character components with proper links
  main_chars = character_type == "simplified" ? word.simplified : word.traditional
  characters = split_into_characters(main_chars)

  if length(characters) > 1  # Only show components for multi-character words
    content *= "\n\n## Character Components\n"
    for char in characters
      link = get_character_link(char, char_info_map)
      if haskey(char_info_map, char)
        char_info = char_info_map[char]
        if char_info.is_standalone_word
          content *= "- $link (standalone word)\n"
        else
          content *= "- $link (character component)\n"
        end
      else
        content *= "- $link\n"
      end
    end
  end

  return content
end

# **NEW**: Create content for non-standalone character files
"""
    create_character_markdown_content(char_info::CharacterInfo) -> String

Create markdown content for a character-only file (characters not found as standalone words).
"""
function create_character_markdown_content(char_info::CharacterInfo)
  content = "*Note: This character does not appear as a standalone word in the selected HSK levels.*\n\n"
  return content
end

# **NEW**: Cleanup orphaned files
"""
    cleanup_orphaned_files(output_dir::String, valid_filenames::Set{String})

Remove any files that shouldn't exist (like empty character files when full files exist).
"""
function cleanup_orphaned_files(output_dir::String, valid_filenames::Set{String})
  if !isdir(output_dir)
    return
  end

  removed_count = 0
  for filename in readdir(output_dir)
    if endswith(filename, ".md") && !(filename in valid_filenames)
      filepath = joinpath(output_dir, filename)
      try
        rm(filepath)
        removed_count += 1
      catch e
        # Silent cleanup
      end
    end
  end

  if removed_count > 0
    println("Removed $removed_count orphaned files")
  end
end

"""
    create_obsidian_vault(words::Vector{ChineseWord}, character_type::String, output_dir::String = "ObsidianVault") -> Int

Create Obsidian vault with markdown files for all words and their character connections.
Enhanced to include comprehensive character meanings and proper link management.
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

  # **NEW**: Build enhanced character info map for proper link management
  char_info_map = build_character_info_map(words, character_type)

  # Also build original character meanings map for backward compatibility
  char_meanings_map = build_character_meanings_map(words, character_type)

  println("Generating markdown files...")
  files_created = 0
  valid_filenames = Set{String}()

  # Generate files for all words (including standalone characters)
  for word in words
    # **NEW**: Use enhanced content creation with proper character links
    content = create_enhanced_markdown_content(word, char_info_map, character_type)
    filename = create_filename(word, character_type)
    filepath = joinpath(output_dir, filename)

    push!(valid_filenames, filename)

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

  # **NEW**: Generate files for characters that are NOT standalone words
  for (char, char_info) in char_info_map
    if !char_info.is_standalone_word
      content = create_character_markdown_content(char_info)
      filename = char_info.filename
      filepath = joinpath(output_dir, filename)

      push!(valid_filenames, filename)

      try
        open(filepath, "w") do file
          write(file, content)
        end
        files_created += 1
      catch e
        println("Warning: Could not create character file $filename")
      end
    end
  end

  # **NEW**: Clean up any orphaned files
  cleanup_orphaned_files(output_dir, valid_filenames)

  println("Created $files_created markdown files in $output_dir")
  return files_created
end

"""
    process_hsk_data(levels::Vector{Int}, character_type::String) -> Vector{ChineseWord}

Main function to load and process selected HSK data with HSK level tracking.
"""
function process_hsk_data(levels::Vector{Int}, character_type::String)
  println("Starting HSK Character Map generation...")

  # Load selected HSK data with level tracking
  raw_data_with_levels = load_selected_hsk_data(levels)

  if isempty(raw_data_with_levels)
    throw(ErrorException("No HSK data could be loaded. Please check data files."))
  end

  # Parse into ChineseWord structs
  println("Parsing word data...")
  words = ChineseWord[]
  skipped = 0

  for (word_data, hsk_level) in raw_data_with_levels
    parsed_word = parse_hsk_word(word_data, character_type, hsk_level)
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

    # Create Obsidian vault with enhanced link management
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
