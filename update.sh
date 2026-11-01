#!/usr/bin/env bash
# Re-resolve runtime dependencies using the same uv version as the image build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TOOLS_IMAGE="$(docker build --platform linux/amd64 --quiet --target dependency-tools "$ROOT")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$ROOT/requirements.in" "$WORK/requirements.in"
docker run --rm --platform linux/amd64 --entrypoint /usr/local/bin/uv --user "$(id -u):$(id -g)" \
    -e UV_CACHE_DIR=/work/.uv-cache -e TMPDIR=/work -v "$WORK:/work" -w /work \
    "$TOOLS_IMAGE" pip compile requirements.in \
    --python-version 3.13 --python-platform x86_64-manylinux_2_36 \
    --generate-hashes --only-binary :all: --no-header \
    --output-file requirements.txt "$@"
mv "$WORK/requirements.txt" "$ROOT/requirements.txt"
