#!/bin/bash

# Script to delete all .md files in ObsidianVault/ directory

VAULT_DIR="ObsidianVault"

# Check if the directory exists
if [ ! -d "$VAULT_DIR" ]; then
    echo "Error: Directory $VAULT_DIR does not exist"
    exit 1
fi

# Find and count .md files
md_files=$(find "$VAULT_DIR" -name "*.md" -type f)
file_count=$(echo "$md_files" | grep -c "\.md$" 2>/dev/null || echo "0")

# Check if .obsidian directory exists
obsidian_dir="$VAULT_DIR/.obsidian"
obsidian_exists=false
if [ -d "$obsidian_dir" ]; then
    obsidian_exists=true
fi

# Display what will be deleted
if [ "$file_count" -eq 0 ] && [ "$obsidian_exists" = false ]; then
    echo "No .md files or .obsidian directory found in $VAULT_DIR"
    exit 0
fi

echo "Items to delete:"
if [ "$file_count" -gt 0 ]; then
    echo "- $file_count .md files"
fi
if [ "$obsidian_exists" = true ]; then
    echo "- .obsidian directory"
fi

# Ask for confirmation
read -p "Do you want to delete these items? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Delete .md files
    if [ "$file_count" -gt 0 ]; then
        find "$VAULT_DIR" -name "*.md" -type f -delete
        echo "All .md files have been deleted"
    fi

    # Delete .obsidian directory
    if [ "$obsidian_exists" = true ]; then
        rm -rf "$obsidian_dir"
        echo ".obsidian directory has been deleted"
    fi

    echo "Cleanup completed"
else
    echo "Operation cancelled"
fi
