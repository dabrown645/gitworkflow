#!/bin/bash

# Rust Plugin for Git Worktree Plugin System
# Handles Rust projects with Cargo

plugin_detect() {
    # Check if this is a Rust project
    [[ -f "Cargo.toml" ]] && return 0 || return 1
}

plugin_setup_worktree() {
    local worktree_dir="$1"
    local main_worktree="../main"
    
    echo "Setting up Rust project in: $worktree_dir"
    
    cd "$worktree_dir"
    
    # Share target directory from main worktree if it exists
    if [[ -d "$main_worktree/target" ]]; then
        echo "🦀 Sharing target directory from main worktree"
        if ln -sf "$main_worktree/target" target 2>/dev/null; then
            echo "✓ Created symlink to target directory"
        else
            echo "⚠️  Symlink failed, will build separately"
        fi
    fi
    
    # Ensure dependencies are fetched
    if command -v cargo >/dev/null 2>&1; then
        echo "🦀 Fetching dependencies..."
        if cargo check 2>/dev/null; then
            echo "✓ Dependencies fetched and project builds"
        else
            echo "⚠️  cargo check failed, run 'cargo build' manually"
        fi
    else
        echo "❌ Cargo not found"
        return 1
    fi
    
    # Show project info
    if [[ -f "Cargo.toml" ]]; then
        local package_name
        package_name=$(grep '^name = ' Cargo.toml | head -1 | cut -d'"' -f2 || echo "unknown")
        echo "📋 Project: $package_name"
    fi
    
    return 0
}

plugin_cleanup_worktree() {
    local worktree_dir="$1"
    
    echo "Cleaning up Rust project in: $worktree_dir"
    
    cd "$worktree_dir"
    
    # Remove target symlink if it exists
    if [[ -L "target" ]]; then
        echo "🗑️  Removing target symlink"
        rm target
        echo "✓ Removed symlink"
    fi
    
    return 0
}

plugin_list_status() {
    if ! plugin_detect; then
        return 1
    fi
    
    local package_name="unknown"
    local package_version="unknown"
    local build_status="unknown"
    
    # Get project info from Cargo.toml
    if [[ -f "Cargo.toml" ]]; then
        package_name=$(grep '^name = ' Cargo.toml | head -1 | cut -d'"' -f2 || echo "unknown")
        package_version=$(grep '^version = ' Cargo.toml | head -1 | cut -d'"' -f2 || echo "unknown")
    fi
    
    # Check target directory status
    if [[ -d "target" ]]; then
        if [[ -L "target" ]]; then
            build_status="shared (symlink)"
        else
            build_status="built"
        fi
    else
        build_status="not built"
    fi
    
    # Display status
    echo "  🦀 Rust Project"
    echo "    Name: $package_name"
    echo "    Version: $package_version"
    echo "    Build Status: $build_status"
    
    # Show if cargo is available
    if command -v cargo >/dev/null 2>&1; then
        local rust_version
        rust_version=$(rustc --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
        echo "    Rust Version: $rust_version"
    else
        echo "    Rust: not installed"
    fi
    
    return 0
}