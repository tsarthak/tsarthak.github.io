---
title: "Moving to Cloudflare Pages"
date: 2026-04-02 03:00:00 -0400
categories: [Infrastructure]
tags: [cloudflare, jekyll, github-pages, migration]
toc: true
---

This site just moved from GitHub Pages to Cloudflare Pages. Here's the why and the how.

## Why move?

GitHub Pages works fine for basic Jekyll hosting, but Cloudflare Pages gives me a few things I wanted:

- **Faster global CDN** — Cloudflare's edge network is hard to beat
- **Preview deployments** — every PR gets its own URL automatically
- **More control** — headers, redirects, and eventually Workers if I need server-side logic

The site is still Jekyll with the [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme, still hosted from a Git repo, still just markdown files. The only thing that changed is where it builds and deploys.

## What changed in the repo

Not much, honestly:

1. **Removed** the GitHub Actions workflow (`.github/workflows/pages-deploy.yml`)
2. **Added** a `Gemfile.lock` — Cloudflare's build system needs it to install gems
3. **Added** a `.ruby-version` file — tells Cloudflare which Ruby to use
4. **Updated** `_config.yml` to point at `tsarthak.pages.dev` instead of `tsarthak.github.io`
5. **Added** a `justfile` for local dev commands (`just serve`, `just build`, `just new-post`)

## The Cloudflare setup

In the Cloudflare dashboard: Workers & Pages → Create → Connect to Git → pick the repo. Build settings:

| Setting | Value |
|---|---|
| Build command | `bundle exec jekyll build` |
| Output directory | `_site` |

Three environment variables are critical:

- `RUBY_VERSION` = `3.2.11`
- `JEKYLL_ENV` = `production`
- `BUNDLE_WITHOUT` = `` (empty string — without this, Cloudflare skips gems and the build fails silently)

That last one is the only real gotcha.

## Local development

```bash
just install  # bundle install
just serve    # localhost:4000 with live reload
just build    # production build
just new-post "Some Title"  # scaffolds a new post
```

Managed by [mise](https://mise.jdx.dev/) for Ruby versioning and [just](https://github.com/casey/just) as the command runner. Neither is needed on Cloudflare's side — they're local-only tools.

## What's next

Writing things down as I build them. Tech dumps, quick references, and the occasional deep dive.
