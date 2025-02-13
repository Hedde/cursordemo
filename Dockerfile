# ------------------------------------------------------------
# Base image: Elixir + Alpine
# ------------------------------------------------------------
FROM elixir:1.18-alpine

# ------------------------------------------------------------
# Install build dependencies:
#   - build-base for native compilation (e.g. NIFs)
#   - nodejs & npm for assets (esbuild/tailwind)
#   - inotify-tools for live reload
#   - git (sometimes needed by deps)
# ------------------------------------------------------------
RUN apk update && apk add --no-cache \
    build-base \
    nodejs \
    npm \
    inotify-tools \
    git

# ------------------------------------------------------------
# Install Hex, Rebar, and the Phoenix project generator
# ------------------------------------------------------------
RUN mix local.hex --force \
 && mix local.rebar --force \
 && mix archive.install hex phx_new 1.7.19 --force

# ------------------------------------------------------------
# Set working directory
# ------------------------------------------------------------
WORKDIR /app

# We won't specify CMD here because we'll use docker-compose
# to define how the container runs in different scenarios.
