#!/usr/bin/env bash
# Update the project lock using the same Debian Python and uv as the image build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TOOLS_IMAGE="$(docker build --platform linux/amd64 --quiet --target dependency-tools "$ROOT")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$ROOT/pyproject.toml" "$WORK/pyproject.toml"
if [[ -f "$ROOT/uv.lock" ]]; then
    cp "$ROOT/uv.lock" "$WORK/uv.lock"
fi
docker run --rm --platform linux/amd64 --entrypoint /usr/local/bin/uv --user "$(id -u):$(id -g)" \
    -e UV_CACHE_DIR=/work/.uv-cache -e TMPDIR=/work -e UV_PYTHON_DOWNLOADS=never \
    -v "$WORK:/work" -w /work \
    "$TOOLS_IMAGE" lock --python /usr/bin/python3 --no-build "$@"
mv "$WORK/uv.lock" "$ROOT/uv.lock"
