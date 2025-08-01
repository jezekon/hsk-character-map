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

if [ "$file_count" -eq 0 ]; then
    echo "No .md files found in $VAULT_DIR"
    exit 0
fi

echo "Found $file_count .md files in $VAULT_DIR"

# Ask for confirmation
read -p "Do you want to delete all .md files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Delete the files
    find "$VAULT_DIR" -name "*.md" -type f -delete
    echo "All .md files have been deleted"
else
    echo "Operation cancelled"
fi
