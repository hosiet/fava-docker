ARG BEANCOUNT_VERSION=3.1.0
ARG FAVA_VERSION=v1.30.5

ARG NODE_BUILD_IMAGE=22-bookworm
FROM node:${NODE_BUILD_IMAGE} AS node_build_env
ARG FAVA_VERSION

WORKDIR /tmp/build
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

# Why not use `python:bookworm`? Because the final app is served by
# distroless Python image, which is Debian + Python from Debain APT
# repo. The python intepreter in the `python:bookworm` image is not from
# Debian APT repo.
FROM debian:bookworm AS build_env
ARG BEANCOUNT_VERSION

RUN apt-get update
RUN apt-get install -y build-essential libxml2-dev libxslt-dev curl \
        python3 libpython3-dev python3-pip git python3-venv bison flex


ENV PATH="/app/bin:$PATH"
RUN python3 -mvenv /app
COPY --from=node_build_env /tmp/build/fava /tmp/build/fava

WORKDIR /tmp/build
RUN git clone https://github.com/beancount/beancount

WORKDIR /tmp/build/beancount
RUN git checkout ${BEANCOUNT_VERSION}

RUN CFLAGS=-s pip3 install -U /tmp/build/beancount
RUN pip3 install -U /tmp/build/fava
ADD requirements.txt .
RUN pip3 install --require-hashes -U -r requirements.txt
RUN pip3 install git+https://github.com/beancount/beanprice.git@f649ae69edd5a8c7ee2618dfebd219cc0119635f
RUN pip3 install git+https://github.com/andreasgerstmayr/fava-portfolio-returns.git@e5dc9cf913dbff2b3d5467e36b6881a1fcebcce4
RUN pip3 install git+https://github.com/andreasgerstmayr/fava-dashboards@0923c493c2c296ff37705f3659d4d4977c2f2b56

RUN pip3 uninstall -y pip

RUN find /app -name __pycache__ -exec rm -rf -v {} +

FROM gcr.io/distroless/python3-debian12
COPY --from=build_env /app /app

# Default fava port number
EXPOSE 5000

ENV BEANCOUNT_FILE=""

ENV FAVA_HOST="0.0.0.0"
ENV PATH="/app/bin:$PATH"

ENTRYPOINT ["fava"]
