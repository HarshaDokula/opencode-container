# OpenCode Docker Runner

Docker-based setup for running [OpenCode](https://github.com/anomalyco/opencode) — an open-source AI coding agent — on any machine with Docker and Docker Compose.

## Prerequisites

- [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/)
- A provider API key (e.g. [Anthropic](https://console.anthropic.com/), [OpenAI](https://platform.openai.com/), [Groq](https://console.groq.com/))

## Quick Start

```bash
# 1. Clone and enter the repo
git clone <repo-url> opencode
cd opencode

# 2. Create your environment file and add your API key(s)
cp .env.example .env
# Edit .env and set at least one provider key, e.g.:
#   ANTHROPIC_API_KEY=sk-ant-...

# 3. Build the image: pulls latest upstream opencode, then adds git
make build

# 4. Run OpenCode
make run
```

By default the container mounts `./workspace` as the working directory. Create projects there or override it:

```bash
make run WORK_DIR=/path/to/your/project
```

## Commands

| Command       | Description                                              |
| ------------- | -------------------------------------------------------- |
| `make build`  | Pull latest upstream OpenCode, then build local image (+git) |
| `make pull`   | Pull the upstream image without git (for reference) |
| `make run`    | Start an interactive OpenCode session                    |
| `make shell`  | Open a bash shell inside the container (for debugging)   |
| `make clean`  | Tear down orphaned containers                            |

## Configuration

### API Keys (`.env`)

Copy `.env.example` to `.env` and fill in keys for the providers you intend to use:

| Variable                | Provider      |
| ----------------------- | ------------- |
| `ANTHROPIC_API_KEY`     | Anthropic     |
| `OPENAI_API_KEY`        | OpenAI        |
| `GOOGLE_API_KEY`        | Google AI     |
| `GROQ_API_KEY`          | Groq          |
| `OPENROUTER_API_KEY`    | OpenRouter    |
| `MISTRAL_API_KEY`       | Mistral       |
| `DEEPSEEK_API_KEY`      | DeepSeek      |
| `XAI_API_KEY`           | xAI (Grok)    |
| `AZURE_OPENAI_API_KEY`  | Azure OpenAI  |

### Model Selection (`config/opencode.json`)

Set the default model in `config/opencode.json` using `provider/model` format:

```json
{
  "model": "anthropic/claude-sonnet-4-20250514"
}
```

The config is mounted into the container at `/root/.config/opencode/opencode.json`. See the [OpenCode docs](https://opencode.ai/docs) for all configuration options.

### Provider Login (`.env` vs `/connect`)

Two ways to authenticate:

- **API keys** — set them in `.env` (see above). Nothing is written to disk.
- **`/connect` inside the TUI** — opencode saves the credential to its data
directory (`~/.local/share/opencode/auth.json`). That directory is bind-mounted
from `./data` so logins survive container restarts.

Do not commit `./data` — it contains credentials (it is gitignored). Delete it
to revoke stored logins.

### Working Directory

The default workspace directory is `./workspace` (auto-created on first run). To point it at another directory, either:

- Set `WORK_DIR` in `.env`:
  ```env
  WORK_DIR=/home/me/my-project
  ```
- Or pass it on the command line:
  ```bash
  make run WORK_DIR=/home/me/my-project
  ```

## File Layout

```
.
├── .dockerignore       # Keeps the build context small
├── .env.example        # Template for API keys
├── .gitignore          # Ignores .env and workspace/
├── Dockerfile          # Upstream opencode + git
├── Makefile            # Convenience targets
├── README.md
├── config/
│   └── opencode.json     # OpenCode agent configuration
├── data/               # Persisted opencode state — auth.json from /connect
├── docker-compose.yaml   # Container definition
└── workspace/            # Default mounted workspace (gitignored)
```

## Git support

The upstream OpenCode image is Alpine-based and does **not** include `git`.
This repo builds a local image (see `Dockerfile`) that adds git, a default
`user.name`/`user.email` identity, and a global `safe.directory *` so
bind-mounted repos owned by the host user work without "dubious ownership"
errors. Override the identity per-repo with:

```bash
git config user.name "Your Name"
git config user.email "you@example.com"
```

## Troubleshooting

**"No services to build" on `make build`** — Ensure you're using the current Makefile which calls `docker compose build` (not `pull`). Use `make pull` only if you want the bare upstream image.

**Configuration is invalid** — Make sure `config/opencode.json` uses string format for the model field (`"provider/model"`), not an object.

**`/connect` login is lost on exit** — Logins live in `~/.local/share/opencode`
inside the container. This repo bind-mounts that path from `./data`; make sure the
mount exists in `docker-compose.yaml` and re-run `make run` (the `setup` target
creates `./data` automatically). If you upgraded from an older version of this
repo, existing credentials must be re-entered once.

**Permission errors on workspace files** — Files created inside the container are owned by root. Adjust ownership from the host as needed, or set `HOST_UID`/`HOST_GID` in the Makefile if your setup requires it.
