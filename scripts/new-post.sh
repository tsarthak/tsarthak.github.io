#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 \"My Post Title\""
    exit 1
fi

title="$1"
datestamp=$(date +%Y-%m-%d)
timestamp=$(date +%H%M%S)
frontmatter_date=$(date +"%Y-%m-%d %H:%M:%S %z")
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
file="_posts/${datestamp}-${timestamp}-${slug}.md"

if [ -f "$file" ]; then
    echo "Error: $file already exists"
    exit 1
fi

cat > "$file" << EOF
---
title: "${title}"
date: ${frontmatter_date}
categories: []
tags: []
toc: true
---

Write your post here.
EOF

echo "Created: $file"
