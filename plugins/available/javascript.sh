#!/bin/bash

# JavaScript Plugin for Git Worktree Plugin System
# Handles Node.js projects with npm/yarn/pnpm

# Plugin Interface Functions

plugin_detect() {
    # Check if this is a JavaScript project
    [[ -f "package.json" ]] && return 0 || return 1
}

plugin_setup_worktree() {
    local worktree_dir="$1"
    local main_worktree="../main"
    
    echo "Setting up JavaScript project in: $worktree_dir"
    
    cd "$worktree_dir"
    
    # Share node_modules from main worktree if it exists
    if [[ -d "$main_worktree/node_modules" ]]; then
        echo "📦 Sharing node_modules from main worktree"
        if ln -sf "$main_worktree/node_modules" node_modules 2>/dev/null; then
            echo "✓ Created symlink to node_modules"
        else
            echo "⚠️  Symlink failed, attempting to copy..."
            if cp -al "$main_worktree/node_modules" node_modules 2>/dev/null; then
                echo "✓ Copied node_modules from main worktree"
            else
                echo "❌ Failed to share node_modules"
            fi
        fi
    fi
    
    # Install dependencies if node_modules doesn't exist
    if [[ ! -d "node_modules" && -f "package.json" ]]; then
        echo "📦 Installing dependencies..."
        
        # Try different package managers in order of preference
        if command -v pnpm >/dev/null 2>&1 && [[ -f "pnpm-lock.yaml" ]]; then
            pnpm install && echo "✓ Installed with pnpm"
        elif command -v yarn >/dev/null 2>&1 && [[ -f "yarn.lock" ]]; then
            yarn install && echo "✓ Installed with yarn"
        elif command -v npm >/dev/null 2>&1; then
            npm install && echo "✓ Installed with npm"
        else
            echo "❌ No package manager found (npm/yarn/pnpm)"
            return 1
        fi
    fi
    
    # Show project info if available
    if [[ -f "package.json" ]] && command -v node >/dev/null 2>&1; then
        local project_name
        local project_version
        project_name=$(node -p "require('./package.json').name" 2>/dev/null || echo "unknown")
        project_version=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
        echo "📋 Project: $project_name v$project_version"
    fi
    
    return 0
}

plugin_cleanup_worktree() {
    local worktree_dir="$1"
    
    echo "Cleaning up JavaScript project in: $worktree_dir"
    
    cd "$worktree_dir"
    
    # Remove node_modules symlink if it exists
    if [[ -L "node_modules" ]]; then
        echo "🗑️  Removing node_modules symlink"
        rm node_modules
        echo "✓ Removed symlink"
    fi
    
    # Clean up npm cache files if they exist
    if [[ -d ".npm" ]]; then
        echo "🗑️  Cleaning .npm cache"
        rm -rf .npm
    fi
    
    return 0
}

plugin_list_status() {
    if ! plugin_detect; then
        return 1
    fi
    
    local project_name="unknown"
    local project_version="unknown"
    local package_manager="unknown"
    local deps_status="missing"
    
    # Get project info
    if command -v node >/dev/null 2>&1 && [[ -f "package.json" ]]; then
        project_name=$(node -p "require('./package.json').name" 2>/dev/null || echo "unknown")
        project_version=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
    fi
    
    # Determine package manager
    if [[ -f "pnpm-lock.yaml" ]]; then
        package_manager="pnpm"
    elif [[ -f "yarn.lock" ]]; then
        package_manager="yarn"
    elif [[ -f "package-lock.json" ]]; then
        package_manager="npm"
    fi
    
    # Check dependencies status
    if [[ -d "node_modules" ]]; then
        if [[ -L "node_modules" ]]; then
            deps_status="shared (symlink)"
        else
            deps_status="installed"
        fi
    fi
    
    # Display status
    echo "  📦 JavaScript Project"
    echo "    Name: $project_name"
    echo "    Version: $project_version"
    echo "    Package Manager: $package_manager"
    echo "    Dependencies: $deps_status"
    
    # Show package scripts if available
    if command -v node >/dev/null 2>&1 && [[ -f "package.json" ]]; then
        local scripts_count
        scripts_count=$(node -p "Object.keys(require('./package.json').scripts || {}).length" 2>/dev/null || echo "0")
        if [[ "$scripts_count" -gt 0 ]]; then
            echo "    Scripts: $scripts_count available"
        fi
    fi
    
    return 0
}