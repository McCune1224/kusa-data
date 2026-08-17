# Build stage: install deps, compile the app, build assets, create a release.
FROM elixir:1.20.2-otp-29-slim AS build

# Build-time dependencies (git for hex git deps like heroicons, build tools for
# any NIFs). esbuild/tailwind ship prebuilt binaries, so no node is needed.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential git ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Hex and Rebar
RUN mix local.hex --force \
    && mix local.rebar --force

WORKDIR /app

ENV MIX_ENV=prod

# Fetch and compile deps first so dependency layers stay cached.
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod \
    && mix deps.compile

# Copy app source, then build+digest static assets and compile.
COPY assets ./assets
COPY config ./config
COPY lib ./lib
COPY priv ./priv

RUN mix compile \
    && mix assets.setup \
    && mix assets.deploy

# Build the production release (bundles ERTS, so the runtime image needs no Elixir).
RUN mix release

# Runtime stage: minimal image with just enough libs for the BEAM.
# Must match the build stage's Debian release (trixie) so glibc versions align.
FROM debian:trixie-slim AS app

# libssl3t64 for HTTPS/crypto, libncurses6 for the BEAM, locales for proper encoding.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends libssl3t64 libncurses6 locales ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Generate an en_US locale.
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Run as a non-root user.
RUN useradd --create-home --shell /bin/bash appuser \
    && mkdir -p /app \
    && chown -R appuser:appuser /app

USER appuser
WORKDIR /app

COPY --from=build --chown=appuser:appuser /app/_build/prod/rel/kusa_data/ ./

# Start the web server on boot. Railway sets PORT, SECRET_KEY_BASE, PHX_HOST,
# ACCESS_TOKEN, and optionally REDIS_URL (see config/runtime.exs).
ENV PHX_SERVER=true

EXPOSE 4000

CMD ["/app/bin/kusa_data", "start"]
