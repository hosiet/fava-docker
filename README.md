# fava-docker

A Debian 13 / distroless image for [Fava](https://beancount.github.io/fava/)
and Beancount 3, with Dashboards, Portfolio Returns and ledger plugins.
This repository maintains the `hosiet/fava-beancount-v3` image recipe.

The current runtime uses Fava 1.30.16, Beancount 3.2.3, Dashboards 2.0.2 and
Portfolio Returns 2.7.0. Python 3.13 on **Linux amd64** is the supported build
target. The Compose and dependency-update commands select that platform
explicitly.

## Build and run

Install Docker with the Compose plugin, then place your ledger and its
included files under `mymoney/`, with `main.bean` as the entry point.
Build the image locally and start the service:

```sh
docker compose build --pull
docker compose up -d --no-build --pull never
docker compose ps
```

Open <http://127.0.0.1:5002>. Compose uses the local image tag
`hosiet/fava-beancount-v3:local`; the commands above build it from this checkout.
The container runs as UID/GID 1000 by default. Its ledger mount is writable
for Fava's editor, document uploads and Beancount's cache, so the selected user
must have access to that directory.

Override the defaults through environment variables or an ignored `.env`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `FAVA_IMAGE` | `hosiet/fava-beancount-v3:local` | Local image tag to build and run |
| `FAVA_UID`, `FAVA_GID` | `1000`, `1000` | Container user and group |
| `FAVA_PORT` | `5002` | Host port, bound to `127.0.0.1` |
| `FAVA_LEDGER_DIR` | `./mymoney` | Host ledger directory |
| `FAVA_LEDGER_FILE` | `main.bean` | Entry file relative to that directory |

For example, to match the current user's file permissions:

```sh
export FAVA_UID="$(id -u)" FAVA_GID="$(id -g)"
docker compose up -d --no-build --pull never
```

To use the Docker CLI directly:

```sh
docker build --pull --platform linux/amd64 -t hosiet/fava-beancount-v3:local .
docker run --rm --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -p 127.0.0.1:5002:5000 -v "$PWD/mymoney:/bean" \
  -e BEANCOUNT_FILE=/bean/main.bean \
  hosiet/fava-beancount-v3:local
```

The image accepts Fava CLI arguments and the `BEANCOUNT_FILE` environment
variable. `FAVA_HOST` defaults to `0.0.0.0` inside the container. For access
from other machines, configure a reverse proxy with authentication and TLS.
The Compose health check follows the initial redirect to the ledger page.

## Build and dependency maintenance

Fava's wheel includes its prebuilt frontend. All runtime dependencies are
installed from wheels, so Node, Git and a compiler are unnecessary for the
build. The build-context allowlist includes only `Dockerfile`,
`pyproject.toml` and `uv.lock`; ledger files, attachments and repository history
stay outside the build context.

`pyproject.toml` declares the direct application and plugin dependencies and
requires Python 3.13. `uv.lock` records the resolved runtime versions, package
sources and archive hashes for Linux amd64. The project uses `package = false`
because it assembles third-party software rather than installing its own
Python package.

The build runs `uv sync --locked --no-dev --no-build`: the lock must match the
project metadata, development dependencies are omitted, and source builds
are disabled. It selects `/usr/bin/python3` explicitly and disables automatic
Python downloads, preserving Debian's interpreter in the distroless runtime.

To change a direct dependency:

1. Edit its version in `pyproject.toml`.
2. Run `./update.sh` and review the `uv.lock` diff.
3. Rebuild the image with `docker compose build --pull`.

`update.sh` uses the Dockerfile's Debian `dependency-tools` stage with the same
pinned uv binary as the application build. It copies the project metadata and
existing lock into a temporary directory, then replaces `uv.lock` on success.
Python and uv need not be installed on the host. An ordinary run preserves
existing locked versions wherever the dependency constraints still allow them.
To explicitly refresh all allowed dependency versions, run:

```sh
./update.sh --upgrade
```

To refresh one allowed dependency, use `./update.sh --upgrade-package NAME`.
Exact `==` constraints in `pyproject.toml` still apply. If uv is installed on the
host with Python 3.13 available, the corresponding commands are `uv lock`,
`uv lock --upgrade`, and `uv lock --upgrade-package NAME`. Use `uv lock --check`
to check that the lock matches the project without changing it.

The Debian build image, distroless runtime and uv image are pinned by digest.
Refresh those digests during maintenance and keep Debian's Python minor
version aligned between the build and runtime stages. Debian build packages
come from the configured APT repositories; retain the built image when an
exact deployment artifact is needed.

## Deployment updates

Build a new image tag before changing `FAVA_IMAGE`. After switching
with `docker compose up -d --no-build --pull never`, inspect health and logs.
Retain the previous image tag until the deployment is accepted; rollback uses
the previous tag and the same Compose command.
