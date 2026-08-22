# Local image for running OpenCode with git support.
#
# The upstream image (ghcr.io/anomalyco/opencode, built from
# packages/opencode/Dockerfile) is Alpine-based and only ships the opencode
# binary plus ripgrep — git is NOT included, so the agent can't see or use
# the .git metadata of a bind-mounted workspace. This image layers git on top.
FROM ghcr.io/anomalyco/opencode:latest

USER root
RUN apk add --no-cache git \
    && git --version

# Make git usable against bind-mounted workspaces:
#  - allow repos owned by the host user (avoids "dubious ownership" errors
#    if the container is ever run as a non-root user)
#  - provide a default identity so `git commit` works out of the box;
#    override in your own repos with git config user.name/user.email
RUN git config --system --add safe.directory '*' \
    && git config --system user.name "OpenCode Agent" \
    && git config --system user.email "agent@opencode.local"
