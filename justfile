# Use mise to ensure correct Ruby version
set shell := ["mise", "x", "--", "bash", "-c"]

# Default recipe: list available commands
default:
    @just --list

# Install Ruby gems (generates/updates Gemfile.lock)
install:
    bundle install

# Serve locally with live reload (http://localhost:4000)
serve:
    bundle exec jekyll serve --livereload

# Production build to _site/
build:
    JEKYLL_ENV=production bundle exec jekyll build

# Clean build artifacts
clean:
    bundle exec jekyll clean

# Create a new post: just new-post "My Post Title"
new-post title:
    #!/usr/bin/env bash
    set -euo pipefail
    date=$(date +%Y-%m-%d)
    slug=$(echo "{{title}}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    file="_posts/${date}-${slug}.md"
    if [ -f "$file" ]; then
        echo "Error: $file already exists"
        exit 1
    fi
    cat > "$file" << 'FRONTMATTER'
    ---
    title: "{{title}}"
    date: DATEPLACEHOLDER
    categories: []
    tags: []
    toc: true
    ---

    Write your post here.
    FRONTMATTER
    # Fix indentation and date placeholder
    sed -i '' 's/^    //' "$file"
    sed -i '' "s/DATEPLACEHOLDER/${date} 12:00:00 -0400/" "$file"
    echo "Created: $file"
