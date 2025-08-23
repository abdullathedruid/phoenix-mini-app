# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=bookworm-20250811-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.18.4-erlang-26.2.5.14-debian-bookworm-20250811-slim
#
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=26.2.5.14
ARG DEBIAN_VERSION=bookworm-20250811-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# Copy minimal git metadata and compute commit SHA and author without git
COPY .git/HEAD .git/HEAD
COPY .git/refs .git/refs
COPY .git/packed-refs .git/packed-refs
COPY .git/logs/HEAD .git/logs/HEAD
RUN set -e; \
  HEAD_REF=$(cat .git/HEAD | awk '{print $2}'); \
  if [ -n "$HEAD_REF" ]; then \
    if [ -f ".git/$HEAD_REF" ]; then \
      FULL_SHA=$(cat ".git/$HEAD_REF"); \
    else \
      FULL_SHA=$(awk -v ref="$HEAD_REF" '$2==ref {print $1}' .git/packed-refs | tail -n1); \
    fi; \
  else \
    FULL_SHA=$(cat .git/HEAD); \
  fi; \
  SHORT_SHA=$(echo "$FULL_SHA" | head -c12); \
  AUTHOR=$(awk '{a=$0} END{print a}' .git/logs/HEAD | awk -F" " '{print $3}'); \
  echo -n "$SHORT_SHA" > /git_sha; \
  echo -n "$AUTHOR" > /git_author

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY priv priv

COPY lib lib

# Compile the release
RUN mix compile

COPY assets assets

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses5 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/miniapp ./

# Copy git metadata files for runtime access
COPY --from=builder /git_sha /etc/git_sha
COPY --from=builder /git_author /etc/git_author

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
