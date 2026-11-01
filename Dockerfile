# syntax=docker/dockerfile:1
# Refresh these digests deliberately when updating the runtime.
FROM ghcr.io/astral-sh/uv:0.12.12@sha256:73d2665b478d8fa2de1cf105c6841f8e9cb6b09e568fc7700440c09f8fcd7ac4 AS uv
FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4 AS dependency-tools

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates python3 python3-venv \
    && rm -rf /var/lib/apt/lists/*
COPY --from=uv /uv /usr/local/bin/uv
FROM dependency-tools AS build
RUN uv venv --python /usr/bin/python3 /app
COPY requirements.txt /tmp/requirements.txt
RUN uv pip sync --python /app/bin/python --require-hashes --only-binary :all: \
        --no-cache /tmp/requirements.txt

# Both stages use Debian's Python 3.13, keeping compiled wheels compatible.
FROM gcr.io/distroless/python3-debian13@sha256:9a1ed29d41d7695245ff86bc2e08684d3dd253a3f9c8ca45677427f9f4fe3598
COPY --from=build /app /app
ENV PATH="/app/bin:$PATH" \
    BEANCOUNT_FILE="" \
    FAVA_HOST="0.0.0.0" \
    PYTHONDONTWRITEBYTECODE="1"
EXPOSE 5000
ENTRYPOINT ["/app/bin/fava"]
