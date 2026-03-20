ARG BEANCOUNT_VERSION=3.2.0
#ARG FAVA_VERSION=v1.30.12
ARG FAVA_VERSION=d677bc824f0e1a62ad0ffa05e224e35995ff4b5e

ARG NODE_BUILD_IMAGE=24-trixie
FROM node:${NODE_BUILD_IMAGE} AS node_build_env
ARG FAVA_VERSION

WORKDIR /tmp/build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
RUN git clone https://github.com/beancount/fava

RUN apt-get update
RUN apt-get install -y python3-babel

WORKDIR /tmp/build/fava
RUN git checkout ${FAVA_VERSION}
RUN make
RUN rm -rf .*cache && \
    rm -rf .eggs && \
    rm -rf .tox && \
    rm -rf build && \
    rm -rf dist && \
    rm -rf frontend/node_modules && \
    find . -type f -name '*.py[c0]' -delete && \
    find . -type d -name "__pycache__" -delete

# Why not use `python:trixie`? Because the final app is served by
# distroless Python image, which is Debian + Python from Debian APT
# repo. The python interpreter in the `python:trixie` image is not from
# Debian APT repo.
FROM debian:trixie AS build_env
ARG BEANCOUNT_VERSION

RUN apt-get update
RUN apt-get install -y build-essential libxml2-dev libxslt-dev curl \
        python3 libpython3-dev git python3-venv bison flex

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

ENV PATH="/app/bin:$PATH"
ENV VIRTUAL_ENV=/app
RUN python3 -mvenv /app
COPY --from=node_build_env /tmp/build/fava /tmp/build/fava

WORKDIR /tmp/build
RUN git clone https://github.com/beancount/beancount

WORKDIR /tmp/build/beancount
RUN git checkout ${BEANCOUNT_VERSION}

RUN CFLAGS=-s uv pip install --no-cache -U /tmp/build/beancount
RUN uv pip install --no-cache -U /tmp/build/fava
ADD requirements.txt .
RUN uv pip install --no-cache --require-hashes -U -r requirements.txt
RUN uv pip install --no-cache git+https://github.com/beancount/beanprice.git@ab9e0cc2f03029d5af59f5bfcea38f03e271fb3d
RUN uv pip install --no-cache git+https://github.com/andreasgerstmayr/fava-portfolio-returns.git@a9b0298230959db26882405fef50010e885735de
RUN uv pip install --no-cache git+https://github.com/andreasgerstmayr/fava-dashboards@ebbfdb620b5f65986563f3fc50d4280d410b05de

RUN find /app -name __pycache__ -exec rm -rf -v {} +

FROM gcr.io/distroless/python3-debian13
COPY --from=build_env /app /app

# Default fava port number
EXPOSE 5000

ENV BEANCOUNT_FILE=""

ENV FAVA_HOST="0.0.0.0"
ENV PATH="/app/bin:$PATH"

ENTRYPOINT ["fava"]
