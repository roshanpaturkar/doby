# syntax=docker/dockerfile:1.7
#
# Doby — a house-elf for your terminal, built on Hermes Agent.
#
# This Dockerfile fetches Hermes Agent at a pinned ref (HERMES_REF build arg,
# defaults to whatever's in ../HERMES_VERSION when built via install.sh).
# Doby itself is just config + persona + skin + skills — those land via the
# bind-mounted ./data directory at runtime, not in the image.
#
FROM ghcr.io/astral-sh/uv:0.11.6-python3.13-trixie AS uv_source
FROM tianon/gosu:1.19-trixie AS gosu_source
FROM debian:13.4

ARG HERMES_REF=v2026.5.16

ENV PYTHONUNBUFFERED=1
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/.playwright

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential curl nodejs npm python3 ripgrep ffmpeg gcc python3-dev \
    libffi-dev procps git openssh-client docker-cli tini ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Non-root runtime user; UID overridable via HERMES_UID at runtime.
RUN useradd -u 10000 -m -d /opt/data hermes

COPY --chmod=0755 --from=gosu_source /gosu /usr/local/bin/
COPY --chmod=0755 --from=uv_source /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

# ---------- Pull Hermes Agent source ----------
# Bumping the pinned ref is a single-arg rebuild: `docker compose build
# --build-arg HERMES_REF=v2026.5.23`. See scripts/upgrade.sh.
RUN git clone --depth 1 --branch "${HERMES_REF}" \
      https://github.com/NousResearch/hermes-agent.git /opt/hermes

WORKDIR /opt/hermes

# ---------- npm + Playwright ----------
ENV npm_config_install_links=false

RUN npm install --prefer-offline --no-audit && \
    npx playwright install --with-deps chromium --only-shell && \
    (cd web && npm install --prefer-offline --no-audit) && \
    (cd ui-tui && npm install --prefer-offline --no-audit) && \
    npm cache clean --force

# ---------- Python deps ----------
RUN uv sync --frozen --no-install-project --extra all --extra messaging

# ---------- Build TUI + dashboard assets ----------
RUN cd web && npm run build && \
    cd ../ui-tui && npm run build

# ---------- Permissions ----------
USER root
RUN chmod -R a+rX /opt/hermes && \
    chown -R hermes:hermes /opt/hermes/.venv /opt/hermes/ui-tui /opt/hermes/node_modules

# ---------- Editable install ----------
RUN uv pip install --no-cache-dir --no-deps -e "."

# ---------- Doby patch: honor display.compact in config.yaml ----------
# Upstream defines `compact: bool = False` as a parameter default in two
# places, which silently shadows the user's `display.compact: true` in
# config.yaml. Flipping the default to None lets the config-fallback path
# (`compact if compact is not None else CLI_CONFIG[...]`) actually run.
# Safe to drop once https://github.com/NousResearch/hermes-agent fixes it.
# The build fails loudly if the patch can't apply — better than a silent skip.
RUN sed -i 's/    compact: bool = False,/    compact: bool = None,/g' /opt/hermes/cli.py && \
    grep -q "    compact: bool = None," /opt/hermes/cli.py || \
      (echo "FATAL: Doby's compact patch did not land — upstream source format changed?" >&2 && exit 1)

# ---------- Runtime ----------
ENV HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist
ENV HERMES_HOME=/opt/data
ENV PATH="/opt/data/.local/bin:${PATH}"
RUN mkdir -p /opt/data
VOLUME [ "/opt/data" ]
ENTRYPOINT [ "/usr/bin/tini", "-g", "--", "/opt/hermes/docker/entrypoint.sh" ]
