#!/usr/bin/env julia

"""
HSK Character Map - Main Runner Script

This script generates a Chinese-English graphical dictionary for Obsidian
by analyzing HSK vocabulary and creating character relationship connections.

Usage:
    julia main.jl

Output:
    - Creates 'ObsidianVault' directory with markdown files
    - Each file represents a Chinese word with character connections
    - Use with Obsidian to visualize character relationships
"""

using Pkg

# Activate the project environment
Pkg.activate(".")

# Include the main module
include("src/HSKCharacterMap.jl")

# Import and run
using .HSKCharacterMap
HSKCharacterMap.main()
