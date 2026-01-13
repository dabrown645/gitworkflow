#!/bin/bash

# Python Plugin for Git Worktree Plugin System
# Handles Python projects with pip/poetry/requirements

plugin_detect() {
    # Check if this is a Python project
    [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" || -f "Pipfile" || -f "uv.lock" ]] && return 0 || return 1
}

plugin_setup_worktree() {
    local worktree_dir="$1"
    
    echo "Setting up Python project in: $worktree_dir"
    
    cd "$worktree_dir"
    
    # Setup virtual environment if needed
    if [[ -f "pyproject.toml" ]] && grep -q "poetry" pyproject.toml 2>/dev/null; then
        # Poetry project
        if command -v poetry >/dev/null 2>&1; then
            echo "🐍 Setting up Poetry environment..."
            if poetry install; then
                echo "✓ Poetry environment created"
            else
                echo "❌ Poetry install failed"
                return 1
            fi
        else
            echo "❌ Poetry not found"
            return 1
        fi
    elif [[ -f "uv.lock" ]]; then
        # UV project
        if command -v uv >/dev/null 2>&1; then
            echo "🐍 Setting up UV environment..."
            if uv sync; then
                echo "✓ UV environment created"
            else
                echo "❌ UV sync failed"
                return 1
            fi
        else
            echo "❌ UV not found"
            return 1
        fi
    elif [[ -f "Pipfile" ]]; then
        # Pipenv project
        if command -v pipenv >/dev/null 2>&1; then
            echo "🐍 Setting up Pipenv environment..."
            if pipenv install; then
                echo "✓ Pipenv environment created"
            else
                echo "❌ Pipenv install failed"
                return 1
            fi
        else
            echo "❌ Pipenv not found"
            return 1
        fi
    else
        # Traditional pip setup
        if [[ -f "requirements.txt" ]]; then
            echo "🐍 Installing requirements with pip..."
            if command -v pip >/dev/null 2>&1; then
                if pip install -r requirements.txt; then
                    echo "✓ Requirements installed"
                else
                    echo "❌ pip install failed"
                    return 1
                fi
            else
                echo "❌ pip not found"
                return 1
            fi
        fi
    fi
    
    # Show project info
    if [[ -f "pyproject.toml" ]]; then
        if grep -q "poetry" pyproject.toml 2>/dev/null; then
            local project_name
            if command -v poetry >/dev/null 2>&1; then
                project_name=$(poetry run python -c "import toml; print(toml.load('pyproject.toml').get('tool', {}).get('poetry', {}).get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            fi
            echo "📋 Project: $project_name (Poetry)"
        fi
    fi
    
    return 0
}

plugin_cleanup_worktree() {
    local worktree_dir="$1"
    
    echo "Cleaning up Python project in: $worktree_dir"
    
    cd "$worktree_dir"
    
    # Remove local virtual environments if they exist
    if [[ -d "venv" ]]; then
        echo "🗑️  Removing local venv"
        rm -rf venv
    fi
    
    if [[ -d ".venv" ]]; then
        echo "🗑️  Removing local .venv"
        rm -rf .venv
    fi
    
    # UV creates .venv by default, already handled above
    
    return 0
}

plugin_list_status() {
    if ! plugin_detect; then
        return 1
    fi
    
    local project_name="unknown"
    local project_type="unknown"
    local deps_status="not installed"
    
    # Determine project type and get info
    if [[ -f "uv.lock" ]]; then
        project_type="uv"
        if command -v uv >/dev/null 2>&1; then
            if [[ -f "pyproject.toml" ]]; then
                project_name=$(python -c "import toml; print(toml.load('pyproject.toml').get('project', {}).get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            else
                project_name=$(basename "$(pwd)")
            fi
            if [[ -d ".venv" ]]; then
                deps_status="uv environment"
            fi
        fi
    elif [[ -f "pyproject.toml" ]] && grep -q "poetry" pyproject.toml 2>/dev/null; then
        project_type="poetry"
        if command -v poetry >/dev/null 2>&1; then
            project_name=$(poetry run python -c "import toml; print(toml.load('pyproject.toml').get('tool', {}).get('poetry', {}).get('name', 'unknown'))" 2>/dev/null || echo "unknown")
            if poetry env info --path >/dev/null 2>&1; then
                deps_status="poetry environment"
            fi
        fi
    elif [[ -f "Pipfile" ]]; then
        project_type="pipenv"
        project_name=$(python -c "import toml; print(toml.load('Pipfile').get('packages', {}).get('default', {}).get('__project__', 'unknown'))" 2>/dev/null || echo "unknown")
        if [[ -n "$VIRTUAL_ENV" ]]; then
            deps_status="pipenv environment"
        fi
    elif [[ -f "requirements.txt" ]]; then
        project_type="pip"
        project_name=$(basename "$(pwd)")
        if [[ -d "venv" || -d ".venv" ]]; then
            deps_status="virtual environment"
        fi
    fi
    
    # Display status
    echo "  🐍 Python Project"
    echo "    Name: $project_name"
    echo "    Type: $project_type"
    echo "    Dependencies: $deps_status"
    
    # Show Python version if available
    if command -v python3 >/dev/null 2>&1; then
        local python_version
        python_version=$(python3 --version 2>/dev/null || echo "unknown")
        echo "    Python: $python_version"
    fi
    
    return 0
}