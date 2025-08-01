"""
    HSKCharacterMap

A Julia module for creating a Chinese-English graphical dictionary that analyzes Chinese words
by breaking them down into constituent characters for use with Obsidian's graph view.

This module processes HSK (Hanyu Shuiping Kaoshi) vocabulary data from JSON files and generates
interconnected markdown files showing character relationships.

# Features

  - Loads HSK levels 1-4 vocabulary data
  - Extracts traditional Chinese, simplified Chinese, pinyin, and English meanings
  - Analyzes character-level composition of words
  - Generates Obsidian-compatible markdown files with [[link]] syntax
  - Creates navigable graph showing character connections

# Usage

```julia
using HSKCharacterMap
main()  # Process all data and create Obsidian vault
```
"""
module HSKCharacterMap

using JSON

# Data structures
"""
    ChineseWord

Represents a Chinese word with all its linguistic information.

# Fields

  - `simplified::String`: Simplified Chinese characters
  - `traditional::String`: Traditional Chinese characters
  - `pinyin::String`: Pinyin with tone marks
  - `pinyin_clean::String`: Pinyin without spaces/punctuation for filenames
  - `meaning::String`: English meaning (first definition)
  - `characters::Vector{String}`: Individual characters from traditional form
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
    load_hsk_data(level::Int) -> Vector{Dict}

Load HSK data from JSON file for specified level (1-4).

# Arguments

  - `level::Int`: HSK level (1, 2, 3, or 4)

# Returns

  - `Vector{Dict}`: Array of word dictionaries from JSON file

# Throws

  - `ArgumentError`: If level is not between 1-4
  - `SystemError`: If data file is not found
"""
function load_hsk_data(level::Int)
  if level < 1 || level > 4
    throw(ArgumentError("HSK level must be between 1 and 4, got $level"))
  end

  filename = "data/hsk_raw/$level.json"
  if !isfile(filename)
    throw(SystemError("Data file not found: $filename"))
  end

  println("Loading HSK level $level data from $filename...")
  return JSON.parsefile(filename)
end

"""
    load_all_hsk_data() -> Vector{Dict}

Load HSK data from all available levels (1-4).

Attempts to load each level individually and combines all available data.
Continues processing even if some levels fail to load.

# Returns

  - `Vector{Dict}`: Combined array of all available word dictionaries
"""
function load_all_hsk_data()
  all_data = Dict[]
  for level in 1:4
    try
      level_data = load_hsk_data(level)
      append!(all_data, level_data)
      println("✓ Loaded $(length(level_data)) words from HSK level $level")
    catch e
      println("⚠ Warning: Could not load HSK level $level: $e")
    end
  end
  println("📊 Total words loaded: $(length(all_data))")
  return all_data
end

"""
    clean_pinyin(pinyin::String) -> String

Remove spaces, punctuation, and tone marks from pinyin for use in filenames.

Converts accented characters to base characters and removes all spacing and punctuation
to create filesystem-safe filenames.

# Arguments

  - `pinyin::String`: Pinyin with tone marks and spaces

# Returns

  - `String`: Cleaned pinyin suitable for filenames

# Examples

```julia
clean_pinyin("ài hào")  # returns "aihao"
clean_pinyin("xué shēng")  # returns "xuesheng"
```    # Remove spaces and common punctuation
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

Processes each Unicode character in the string, filtering out whitespace.

# Arguments

  - `word::String`: Chinese word in traditional or simplified characters

# Returns

  - `Vector{String}`: Array of individual character strings
"""
function split_into_characters(word::String)
  return [string(char) for char in word if !isspace(char)]
end

"""
    parse_hsk_word(word_data::Dict) -> Union{ChineseWord, Nothing}

Parse a single HSK word entry from JSON data into a ChineseWord struct.

Extracts simplified, traditional, pinyin, and meaning information from the
structured JSON data format.

# Arguments

  - `word_data::Dict`: Dictionary containing word information from JSON

# Returns

  - `ChineseWord`: Parsed word structure, or `nothing` if parsing fails
"""
function parse_hsk_word(word_data::Dict)
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

    # Split into individual characters using traditional form
    characters = split_into_characters(traditional)

    return ChineseWord(simplified, traditional, pinyin, pinyin_clean, meaning, characters)

  catch e
    return nothing
  end
end

"""
    create_filename(word::ChineseWord) -> String

Create filename following the convention: [Traditional] ([Pinyin with tones]), [Pinyin without spaces/punctuation].md

# Arguments

  - `word::ChineseWord`: Word structure containing naming information

# Returns

  - `String`: Formatted filename string

# Examples

```julia
word = ChineseWord("爱好", "愛好", "ài hào", "aihao", "hobby", ["愛", "好"])
create_filename(word)  # returns "愛好 (ài hào), aihao.md"
```
"""
function create_filename(word::ChineseWord)
  return "$(word.traditional) ($(word.pinyin)), $(word.pinyin_clean).md"
end

"""
    find_character_connections(target_word::ChineseWord, all_words::Vector{ChineseWord}) -> Vector{String}

Find all characters from target_word that exist as standalone words in the dictionary.

Analyzes each character in the target word to see if it exists as an independent
word in the complete dictionary, creating connections for the graph view.

# Arguments

  - `target_word::ChineseWord`: Word to analyze for character connections
  - `all_words::Vector{ChineseWord}`: Complete dictionary for lookup

# Returns

  - `Vector{String}`: Array of filenames for connected character words
"""
function find_character_connections(
  target_word::ChineseWord,
  all_words::Vector{ChineseWord}
)
  connections = String[]

  # Create a lookup dictionary for quick searching
  word_lookup = Dict{String, ChineseWord}()
  for word in all_words
    word_lookup[word.traditional] = word
  end

  # Check each character of the target word
  for char in target_word.characters
    if haskey(word_lookup, char)
      connected_word = word_lookup[char]
      filename = create_filename(connected_word)
      push!(connections, filename)
    end
  end

  return connections
end

"""
    create_markdown_content(word::ChineseWord, connections::Vector{String}) -> String

Create markdown content for a word file.

Generates the content following the specification:

  - Line 1: Traditional Chinese
  - Line 2: English meaning (first from meanings array)
  - Optional: Character connections section with [[link]] syntax

# Arguments

  - `word::ChineseWord`: Word to create content for
  - `connections::Vector{String}`: Array of connected character filenames

# Returns

  - `String`: Complete markdown content for the file
"""
function create_markdown_content(word::ChineseWord, connections::Vector{String})
  content = "$(word.traditional)\n$(word.meaning)"

  # Add connections if any exist
  if !isempty(connections)
    content *= "\n\n## Character Components\n"
    for connection in connections
      # Extract the traditional character from the filename for display
      char_part = split(connection, " (")[1]
      content *= "- [[$char_part]]\n"
    end
  end

  return content
end

"""
    create_obsidian_vault(words::Vector{ChineseWord}, output_dir::String = "ObsidianVault") -> Int

Create Obsidian vault with markdown files for all words and their character connections.

Generates the complete vault structure with interconnected files suitable for
Obsidian's graph view visualization.

# Arguments

  - `words::Vector{ChineseWord}`: Array of all processed words
  - `output_dir::String`: Directory name for the vault (default: "ObsidianVault")

# Returns

  - `Int`: Number of files successfully created
"""
function create_obsidian_vault(
  words::Vector{ChineseWord},
  output_dir::String = "ObsidianVault"
)
  # Create output directory
  if !isdir(output_dir)
    mkdir(output_dir)
    println("📁 Created directory: $output_dir")
  end

  println("🔄 Generating markdown files...")
  files_created = 0

  for word in words
    # Find character connections
    connections = find_character_connections(word, words)

    # Create markdown content
    content = create_markdown_content(word, connections)

    # Create filename
    filename = create_filename(word)
    filepath = joinpath(output_dir, filename)

    # Write file
    try
      open(filepath, "w") do file
        write(file, content)
      end
      files_created += 1

      # Show progress every 100 files
      if files_created % 100 == 0
        println("  ✓ Created $files_created files...")
      end
    catch e
      println("⚠ Warning: Could not create file $filename: $e")
    end
  end

  println("✅ Created $files_created markdown files in $output_dir")
  return files_created
end

"""
    process_hsk_data() -> Vector{ChineseWord}

Main function to load and process all HSK data.

Coordinates the entire data loading and processing pipeline:

 1. Load raw JSON data from all HSK levels
 2. Parse each entry into ChineseWord structures
 3. Filter out invalid entries

# Returns

  - `Vector{ChineseWord}`: Array of successfully processed words
"""
function process_hsk_data()
  println("🚀 Starting HSK Character Map generation...")

  # Load all HSK data
  raw_data = load_all_hsk_data()

  if isempty(raw_data)
    throw(ErrorException("No HSK data could be loaded. Please check data files."))
  end

  # Parse into ChineseWord structs
  println("🔄 Parsing word data...")
  words = ChineseWord[]
  skipped = 0

  for word_data in raw_data
    parsed_word = parse_hsk_word(word_data)
    if parsed_word !== nothing
      push!(words, parsed_word)
    else
      skipped += 1
    end
  end

  println("✅ Successfully parsed $(length(words)) words")
  if skipped > 0
    println("⚠ Skipped $skipped words due to parsing errors")
  end

  return words
end

"""
    main()

Main entry point for the HSK Character Map generation.

Executes the complete pipeline:

 1. Process HSK data from JSON files
 2. Create Obsidian vault with interconnected markdown files
 3. Report results

This function handles all error cases and provides user-friendly feedback.
"""
function main()
  println("🈳 HSK Character Map - Julia Implementation")
  println("=========================================")

  try
    # Process HSK data
    words = process_hsk_data()

    if isempty(words)
      println("❌ Error: No words were successfully processed")
      println("💡 Please check that HSK data files exist in 'data/hsk_raw/' directory")
      return
    end

    # Create Obsidian vault
    files_created = create_obsidian_vault(words)

    println("\n🎉 Processing complete!")
    println("📁 Obsidian vault created with $files_created files")
    println(
      "📖 Open the 'ObsidianVault' folder in Obsidian to view the character relationship graph"
    )
    println("\n📋 Next steps:")
    println("   1. Open Obsidian")
    println("   2. Click 'Open folder as vault'")
    println("   3. Select the 'ObsidianVault' directory")
    println("   4. Open Graph View to see character connections")

  catch e
    println("❌ Error during processing: $e")
    println("💡 Please check that the data files exist in the 'data/hsk_raw/' directory")
    println("📁 Expected files: data/hsk_raw/1.json, data/hsk_raw/2.json, etc.")
  end
end

# Export main functions for external use
export main, process_hsk_data, create_obsidian_vault, ChineseWord

end # module HSKCharacterMap
