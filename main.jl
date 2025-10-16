#!/usr/bin/env julia

# main.jl
#
# Main runner script with HSK and TOCFL support
# Enhanced with duplicate handling - HSK takes precedence over TOCFL
#
# Usage:
#   julia main.jl

using Pkg
Pkg.activate(".")

include("src/HSKCharacterMap.jl")
include("src/TOCFLLoader.jl")

using .HSKCharacterMap
using .TOCFLLoader

"""
    print_warning(msg::String)

Print warning message in yellow/orange color for potential issues.
"""
function print_warning(msg::String)
    leading_newlines = length(match(r"^\n*", msg).match)
    cleaned_msg = lstrip(msg, '\n')

    if leading_newlines > 0
        print("\n" ^ leading_newlines)
    end
    println("\e[1;33m⚠️  [WARNING] $(cleaned_msg)\e[0m")
end

"""
    get_user_source_selection() -> Symbol

Ask user which vocabulary source to use.
Returns :hsk, :tocfl, or :both
"""
function get_user_source_selection()
    println("=" ^ 60)
    println("Chinese Character Map - Vocabulary Source Selection")
    println("=" ^ 60)
    println("\nSelect vocabulary source:")
    println("  1. HSK only")
    println("  2. TOCFL only")
    println("  3. Both HSK and TOCFL")
    print("\nYour choice (1-3, default=1): ")

    input = strip(readline())

    if input == "2"
        println("Selected: TOCFL only\n")
        return :tocfl
    elseif input == "3"
        println("Selected: Both HSK and TOCFL\n")
        return :both
    else
        println("Selected: HSK only\n")
        return :hsk
    end
end

"""
    convert_tocfl_to_chinese_word(tocfl_data::Dict, character_type::String) -> HSKCharacterMap.ChineseWord

Convert TOCFL data dictionary to ChineseWord structure.
"""
function convert_tocfl_to_chinese_word(tocfl_data::Dict, character_type::String)
    # Convert SubString to String explicitly and remove brackets with content
    vocab = String(strip(replace(String(tocfl_data["vocabulary"]), r"\[.*?\]" => "")))
    pinyin = String(strip(replace(String(tocfl_data["pinyin"]), r"\[.*?\]" => "")))

    level_code = String(tocfl_data["level"])

    # Empty meaning (TOCFL doesn't have English translations)
    meaning = ""

    pinyin_clean = HSKCharacterMap.clean_pinyin(pinyin)
    characters = HSKCharacterMap.split_into_characters(vocab)

    # TOCFL uses traditional characters
    traditional = vocab
    simplified = vocab

    return HSKCharacterMap.ChineseWord(
        simplified,
        traditional,
        pinyin,
        pinyin_clean,
        meaning,
        [meaning],
        characters,
        "tocfl-$(level_code)",
    )
end

"""
    remove_duplicates!(all_words::Vector{HSKCharacterMap.ChineseWord}, character_type::String) -> Int

Remove duplicate words between HSK and TOCFL, giving HSK priority.
Returns the number of duplicates removed.
"""
function remove_duplicates!(
    all_words::Vector{HSKCharacterMap.ChineseWord},
    character_type::String,
)
    # Build set of HSK word characters for fast lookup
    hsk_chars = Set{String}()
    for word in all_words
        if startswith(word.hsk_level, "HSK")
            chars = character_type == "simplified" ? word.simplified : word.traditional
            push!(hsk_chars, chars)
        end
    end

    # Count TOCFL words before filtering
    original_tocfl_count = count(w -> startswith(w.hsk_level, "tocfl"), all_words)

    # Filter out TOCFL words that duplicate HSK words
    filter!(all_words) do word
        if startswith(word.hsk_level, "tocfl")
            chars = character_type == "simplified" ? word.simplified : word.traditional
            return !(chars in hsk_chars)
        end
        return true
    end

    # Count TOCFL words after filtering
    new_tocfl_count = count(w -> startswith(w.hsk_level, "tocfl"), all_words)
    duplicates_removed = original_tocfl_count - new_tocfl_count

    return duplicates_removed
end

"""
    main()

Main entry point with unified HSK and TOCFL support.
"""
function main()
    try
        # Get source selection
        source = get_user_source_selection()

        all_words = HSKCharacterMap.ChineseWord[]
        character_type = "traditional"  # Default

        # Load HSK if selected
        if source == :hsk || source == :both
            println("=" ^ 60)
            println("HSK VOCABULARY")
            println("=" ^ 60)

            hsk_levels = HSKCharacterMap.get_user_hsk_levels()
            character_type = HSKCharacterMap.get_user_character_type()

            hsk_words = HSKCharacterMap.process_hsk_data(hsk_levels, character_type)
            append!(all_words, hsk_words)

            println("\n✓ Loaded $(length(hsk_words)) HSK words")
        end

        # Load TOCFL if selected
        if source == :tocfl || source == :both
            println("\n" * "=" ^ 60)
            println("TOCFL VOCABULARY")
            println("=" ^ 60)

            # TOCFL uses traditional characters only
            if source == :tocfl
                character_type = "traditional"
                println("Note: TOCFL uses traditional characters only\n")
            else
                println("Note: Using character type selected for HSK\n")
            end

            tocfl_levels = TOCFLLoader.get_user_tocfl_levels()
            tocfl_excel = "data/tocfl_raw/tocfl_vocabulary.xlsx"

            if !isfile(tocfl_excel)
                println("\n⚠️  Error: TOCFL Excel file not found!")
                println("Expected location: $tocfl_excel")
                println("Please place your TOCFL Excel file in data/tocfl_raw/")
                if source == :tocfl
                    return  # Exit if TOCFL-only mode
                end
            else
                tocfl_data = TOCFLLoader.load_tocfl_data(tocfl_excel, tocfl_levels)

                # Convert TOCFL data to ChineseWord format
                println("\nConverting TOCFL data...")
                tocfl_words =
                    [convert_tocfl_to_chinese_word(d, character_type) for d in tocfl_data]
                append!(all_words, tocfl_words)

                println("✓ Loaded $(length(tocfl_words)) TOCFL words")
            end
        end

        # Handle duplicates if both sources were loaded
        if source == :both
            print_warning(
                "\nLoading both HSK and TOCFL data. HSK words take precedence over TOCFL for duplicate entries.",
            )

            duplicates_removed = remove_duplicates!(all_words, character_type)

            if duplicates_removed > 0
                println(
                    "  Removed $duplicates_removed duplicate TOCFL words (already in HSK)",
                )
            else
                println("  No duplicates found between HSK and TOCFL")
            end
        end

        # Validate we have data
        if isempty(all_words)
            println("\n❌ Error: No vocabulary words loaded")
            return
        end

        # Generate Obsidian vault
        println("\n" * "=" ^ 60)
        println("GENERATING OBSIDIAN VAULT")
        println("=" ^ 60)
        println("\nTotal vocabulary: $(length(all_words)) words")
        println("Character type: $character_type")

        files_created = HSKCharacterMap.create_obsidian_vault(
            all_words,
            character_type,
            "ObsidianVault",
        )

        # Summary
        println("\n" * "=" ^ 60)
        println("✅ PROCESSING COMPLETE!")
        println("=" ^ 60)
        println("\nStatistics:")
        println("  Total words: $(length(all_words))")
        println("  Files created: $files_created")

        # Count by source
        if source == :both
            hsk_count = count(w -> startswith(w.hsk_level, "HSK"), all_words)
            tocfl_count = count(w -> startswith(w.hsk_level, "tocfl"), all_words)
            println("  HSK words: $hsk_count")
            println("  TOCFL words: $tocfl_count")
        end

        println("\nNext steps:")
        println("  1. Open Obsidian")
        println("  2. Click 'Open folder as vault'")
        println("  3. Select the 'ObsidianVault' directory")
        println("  4. Open Graph View to visualize connections")

        println("\nSearch tips:")
        if source != :tocfl
            println("  - Filter HSK: tag:#hsk1 or tag:#hsk2")
        end
        if source != :hsk
            println("  - Filter TOCFL: tag:#tocfl-N1 or tag:#tocfl-L1")
        end

    catch e
        println("\n❌ Error during processing:")
        println(e)
        println("\nStack trace:")
        showerror(stdout, e, catch_backtrace())
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
