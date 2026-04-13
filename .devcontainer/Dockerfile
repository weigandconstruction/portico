# Set versions in docker-compose service definition
ARG ELIXIR_VERSION
ARG ERLANG_VERSION
ARG DEBIAN_VERSION

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-debian-${DEBIAN_VERSION}

# Install needed packages. User creation and shell setup are handled by
# the common-utils devcontainer Feature; Node.js by the node Feature.
RUN apt-get update \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
    gnupg lsb-release curl ca-certificates \
    build-essential inotify-tools unzip \
    watchman \
  # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*
