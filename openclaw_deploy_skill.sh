#!/bin/bash
#
# Deploy script for Holo Polymarket Skill
# Usage: ./openclaw_deploy_skill.sh <target-path>
#

set -e

# Get the directory where this script is located (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <target-path>"
    exit 1
fi

TARGET_PATH="$1"

# Resolve target path
if [[ "$TARGET_PATH" != /* ]]; then
    echo "Error: Target path must be absolute"
    exit 1
fi

echo "Deploying Holo Polymarket to: $TARGET_PATH"

# Check dependencies
echo "Checking dependencies..."
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not installed"
        exit 1
    fi
    echo "  ✅ $cmd found"
done

# Create target directory
mkdir -p "$TARGET_PATH"

# Files and directories to copy
DEPLOY_ITEMS=(
    "SKILL.md"
    "scripts"
)

# Copy each item
for item in "${DEPLOY_ITEMS[@]}"; do
    if [ -e "$SCRIPT_DIR/$item" ]; then
        echo "Copying $item..."
        rm -rf "$TARGET_PATH/$item" 2>/dev/null || true
        cp -r "$SCRIPT_DIR/$item" "$TARGET_PATH/"
    else
        echo "Warning: $item not found, skipping"
    fi
done

echo ""
echo "✅ Deployment complete!"
