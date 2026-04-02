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
    scripts/new-post.sh "{{title}}"
