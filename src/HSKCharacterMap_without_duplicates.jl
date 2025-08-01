#!/usr/bin/env julia

"""
HSK Character Map - Enhanced Julia Implementation with Fixed Link Management

Fixes the issue where characters get both empty files and full files, causing
broken links. Now properly manages character files and updates all references.

Key improvements:
1. Two-pass processing: first collect all standalone characters, then generate files
2. Proper link management to avoid empty character files
3. Cleanup of orphaned files and link updates
4. Character availability tracking in file content
"""

module HSKCharacterMap

using JSON

# Data structures
struct ChineseWord
  simplified::String
  traditional::String
  pinyin::String
  pinyin_clean::String
  meaning::String
  all_meanings::Vector{String}
  characters::Vector{String}
  hsk_level::Int
end

struct CharacterInfo
  character::String
  is_standalone_word::Bool
  filename::String
  all_meanings::Vector{String}
  hsk_levels::Vector{Int}
  compounds_using_it::Vector{String}  # Words that use this character
end

"""
    get_user_hsk_levels() -> Vector{Int}
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
      parts = split(input, "-")
      if length(parts) == 2
        start_level = parse(Int, strip(parts[1]))
        end_level = parse(Int, strip(parts[2]))
        levels = collect(start_level:end_level)
      end
    elseif contains(input, ",")
      parts = split(input, ",")
      levels = [parse(Int, strip(part)) for part in parts]
    else
      levels = [parse(Int, strip(input))]
    end

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
      println("Warning: Could not load HSK level $level")
    end
  end

  println("Total: $(length(all_data)) words")
  return all_data
end

"""
    clean_pinyin(pinyin::String) -> String
"""
function clean_pinyin(pinyin::String)
  cleaned = replace(pinyin, r"[\s\.,;:!?\-()]" => "")

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
"""
function split_into_characters(word::String)
  return [string(char) for char in word if !isspace(char)]
end

"""
    parse_hsk_word(word_data::Dict, character_type::String, hsk_level::Int) -> Union{ChineseWord, Nothing}
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

    meanings = first_form["meanings"]
    if isempty(meanings)
      return nothing
    end

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
    build_character_info_map(words::Vector{ChineseWord}, character_type::String) -> Dict{String, CharacterInfo}

Build comprehensive character information map with proper standalone word detection.
This is the KEY function that fixes the linking issue.
"""
function build_character_info_map(words::Vector{ChineseWord}, character_type::String)
  char_info_map = Dict{String, CharacterInfo}()

  # Create word lookup for fast standalone character detection
  word_lookup = Set{String}()
  word_to_word_map = Dict{String, ChineseWord}()

  for word in words
    lookup_chars = character_type == "simplified" ? word.simplified : word.traditional
    push!(word_lookup, lookup_chars)
    word_to_word_map[lookup_chars] = word
  end

  # First pass: collect all characters and their meanings
  for word in words
    word_chars = character_type == "simplified" ? word.simplified : word.traditional

    for char in split_into_characters(word_chars)
      # Check if this character exists as a standalone word
      is_standalone = char in word_lookup

      # Determine filename
      filename = if is_standalone
        standalone_word = word_to_word_map[char]
        create_filename(standalone_word, character_type)
      else
        "$char.md"  # Simple filename for non-standalone characters
      end

      if haskey(char_info_map, char)
        # Character already exists, merge information
        existing = char_info_map[char]

        # If we found it's a standalone word, update the info
        if is_standalone && !existing.is_standalone_word
          standalone_word = word_to_word_map[char]
          char_info_map[char] = CharacterInfo(
            char,
            true,
            filename,
            union(existing.all_meanings, standalone_word.all_meanings),
            union(existing.hsk_levels, [standalone_word.hsk_level]),
            existing.compounds_using_it
          )
        else
          # Just add this word's meanings
          char_info_map[char] = CharacterInfo(
            char,
            existing.is_standalone_word,
            existing.filename,
            union(existing.all_meanings, word.all_meanings),
            union(existing.hsk_levels, [word.hsk_level]),
            existing.compounds_using_it
          )
        end

        # Add compound word that uses this character
        push!(char_info_map[char].compounds_using_it, word_chars)
      else
        # First time seeing this character
        initial_meanings = is_standalone ? word_to_word_map[char].all_meanings : String[]
        char_info_map[char] = CharacterInfo(
          char,
          is_standalone,
          filename,
          initial_meanings,
          [word.hsk_level],
          [word_chars]
        )
      end
    end
  end

  standalone_count = count(info -> info.is_standalone_word, values(char_info_map))
  println("Mapped $(length(char_info_map)) characters ($standalone_count standalone)")

  return char_info_map
end

"""
    create_filename(word::ChineseWord, character_type::String) -> String
"""
function create_filename(word::ChineseWord, character_type::String)
  main_chars = character_type == "simplified" ? word.simplified : word.traditional
  return "$(main_chars) ($(word.pinyin)), $(word.pinyin_clean).md"
end

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
    create_word_markdown_content(word::ChineseWord, char_info_map::Dict{String, CharacterInfo}, character_type::String) -> String

Create markdown content for a word file with proper character links.
"""
function create_word_markdown_content(
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

"""
    create_character_markdown_content(char_info::CharacterInfo) -> String

Create markdown content for a character-only file (characters not found as standalone words).
"""
function create_character_markdown_content(char_info::CharacterInfo)
  # Note that this character is not a standalone word in the HSK vocabulary
  content = "*Note: This character does not appear as a standalone word in the selected HSK levels.*\n\n"

  return content
end

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
    create_obsidian_vault_fixed(words::Vector{ChineseWord}, character_type::String, output_dir::String = "ObsidianVault") -> Int

Create Obsidian vault with proper link management - NO MORE BROKEN LINKS!
"""
function create_obsidian_vault_fixed(
  words::Vector{ChineseWord},
  character_type::String,
  output_dir::String = "ObsidianVault"
)
  # Create output directory
  if !isdir(output_dir)
    mkdir(output_dir)
  end

  # Build comprehensive character information map
  char_info_map = build_character_info_map(words, character_type)

  println("Generating files...")
  files_created = 0
  valid_filenames = Set{String}()

  # Generate files for all words (including standalone characters)
  for word in words
    content = create_word_markdown_content(word, char_info_map, character_type)
    filename = create_filename(word, character_type)
    filepath = joinpath(output_dir, filename)

    push!(valid_filenames, filename)

    try
      open(filepath, "w") do file
        write(file, content)
      end
      files_created += 1
    catch e
      println("Warning: Could not create file $filename")
    end
  end

  # Generate files for characters that are NOT standalone words
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

  # Clean up any orphaned files
  cleanup_orphaned_files(output_dir, valid_filenames)

  return files_created
end

"""
    process_hsk_data(levels::Vector{Int}, character_type::String) -> Vector{ChineseWord}
"""
function process_hsk_data(levels::Vector{Int}, character_type::String)
  raw_data_with_levels = load_selected_hsk_data(levels)

  if isempty(raw_data_with_levels)
    throw(ErrorException("No HSK data could be loaded. Please check data files."))
  end

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

  println("Parsed $(length(words)) words")
  if skipped > 0
    println("Skipped $skipped invalid entries")
  end

  return words
end

"""
    main()

Main entry point with enhanced link management.
"""
function main()
  println("HSK Character Map")

  try
    # Get user preferences
    levels = get_user_hsk_levels()
    character_type = get_user_character_type()

    # Process HSK data
    words = process_hsk_data(levels, character_type)

    if isempty(words)
      println("Error: No words were successfully processed")
      println("Check that HSK data files exist in data/ directory")
      return
    end

    # Create Obsidian vault with fixed linking
    files_created = create_obsidian_vault_fixed(words, character_type)

    println("Processing complete.")
    println("Created $files_created files")
    println("Character type: $(character_type)")
    println("HSK levels: $(join(levels, ", "))")

  catch e
    println("Error: $e")
    println("Check that data files exist in data/ directory")
    println("Expected: data/hsk_raw/1.json, data/hsk_raw/2.json, etc.")
  end
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
  main()
end

end # module HSKCharacterMapFixed
