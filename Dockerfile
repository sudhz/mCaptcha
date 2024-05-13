# SPDX-FileCopyrightText: 2023 Aravinth Manivannan <realaravinth@batsense.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
FROM node:20 as frontend
RUN set -ex; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends make
RUN mkdir -p /src/docs/openapi/
COPY package.json yarn.lock /src/
COPY docs/openapi/package.json docs/openapi/yarn.lock /src/docs/openapi/
WORKDIR /src
RUN  yarn config set strict-ssl false && yarn install && cd docs/openapi && yarn install
WORKDIR /src
RUN mkdir -p /src/static/cache/bundle
COPY tsconfig.json webpack.config.js jest.config.ts /src/
COPY templates /src/templates/
COPY docs/openapi /src/docs/openapi/
COPY Makefile /src/
COPY scripts /src/scripts
RUN make frontend

FROM rust:latest as rust
WORKDIR /src
COPY . .
COPY --from=frontend /src/static/cache/bundle/ /src/static/cache/bundle/
COPY --from=frontend /src/docs/openapi/dist/ /src/docs/openapi/dist/
RUN cargo --version
RUN make cache-bust
ENV DATABASE_URL=postgresql://test_owner:PIh2eo3AOMiz@ep-dark-mud-a1xe5f14.ap-southeast-1.aws.neon.tech/test?sslmode=require&sslaccept=accept_invalid_certs
RUN cargo build --release

FROM debian:bookworm as mCaptcha
LABEL org.opencontainers.image.source https://github.com/sudhz/mCaptcha
RUN set -ex; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends curl
RUN useradd -ms /bin/bash -u 1001 mcaptcha
WORKDIR /home/mcaptcha
COPY --from=rust /src/target/release/mcaptcha /usr/local/bin/
COPY --from=rust /src/config/default.toml /etc/mcaptcha/config.toml
USER mcaptcha
CMD [ "/usr/local/bin/mcaptcha" ]
