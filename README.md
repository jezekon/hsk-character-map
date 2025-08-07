# HSK Character Map

When learning Chinese, it's hard to remember which words share the same characters. You might know that 学 means "study", but it's not obvious that this same character appears in 学生 (student), 大学 (university), and 学习 (to study). Traditional dictionaries show you one word at a time. This tool shows you how characters connect across your entire HSK vocabulary, making it easier to spot patterns and learn related words together.

**Features:**
- HSK levels 1-7 support
- Traditional and simplified characters
- Visual connections using [Obsidian](https://obsidian.md/) graph view
- Markdown files with translations, character breakdowns and cross-links

This tool creates an interactive dictionary for [Obsidian](https://obsidian.md/) that turns your HSK vocabulary into an interactive map. Open any word and see all the related words that share its characters. You learn connections, not just individual words.

## Visual Example
<div align="center">
<img src="doc/Obsidian_screenshot.png" alt="HSK Character Map in Obsidian Graph View" width="100%">
</div>

## How It Works
Take the word **学习** (to study). It contains two characters that also appear in other words:
- **学** appears in 学生 (student) and 大学 (university)  
- **习** appears in 练习 (practice) and 习惯 (habit)

The tool finds these connections and creates clickable links between related words.
## How to Use

### Option 1: Download Pre-built Obsidian Vaults (Recommended)

1. Go to the [Releases](../../releases) page
2. Download the vault for your desired HSK level(s), for example:
   - `HSK-1-4-Traditional.zip` / `HSK-1-4-Simplified.zip`
3. Extract the zip file
4. Open Obsidian → "Open folder as vault"
5. Select the extracted directory
6. Switch to Graph View to visualize character relationships

### Option 2: Generate Custom Vault with Julia Script

For developers or those wanting specific HSK level combinations:

1. **Prerequisites**: [Julia](https://julialang.org/) 1.11+ with JSON package
2. **Data**: Ensure HSK JSON files are in `data/hsk_raw/` directory
3. **Run**: Execute `julia --project=. main.jl` and follow the prompts to select:
   - HSK levels (e.g., `1-4`, `1,3,5`, or `6`)
   - Character type (traditional or simplified)
4. **Open**: Use the generated `ObsidianVault` directory in Obsidian

## Output Structure

Each word generates a markdown file with:
- HSK level tags (`#hsk1`, `#hsk2`, etc.)
- English meanings
- Character component links organized by:
  - Individual Characters
  - Two-Character Words  
  - Three-Character Words
  - Multi-Character Words

**Example**: `大學生 (dà xué shēng), daxuesheng.md`
```markdown
#hsk1
university student

### All meanings:
- university student
- college student


## Character Components
### Individual Characters:
- [[大 (dà), da]] (big; large; great)
- [[学 (xué), xue]] (to learn)
- [[生 (shēng), sheng]] (to be born)
### Two-Character Words:
- [[大学 (Dà xué), daxue]] (the Great Learning, one of the Four Books 四书 in Confucianism)
- [[学生 (xué sheng), xuesheng]] (student)
```

## Acknowledgments

- Inspired by [Vietnamese Language Graph](https://github.com/DavidASix/vietnamese-language-graph) by DavidASix
- HSK vocabulary data from [Complete HSK Vocabulary](https://github.com/drkameleon/complete-hsk-vocabulary)

