ARG RUBY_VERSION=3.4.1
ARG BASE_IMAGE=ruby:${RUBY_VERSION}-alpine
ARG CACHE_IMAGE=${BASE_IMAGE}

FROM ${CACHE_IMAGE} AS gem-cache
RUN mkdir -p /usr/local/bundle

# base image
FROM ${BASE_IMAGE} AS base
RUN apk add --update sqlite-dev openssl-dev tzdata bash curl zip git
RUN apk add --update build-base
RUN gem install bundler:2.6.9

FROM base AS gems
COPY --from=gem-cache /usr/local/bundle /usr/local/bundle
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Final backend image
FROM base AS deploy

RUN adduser -D app
RUN chown app:app /home/app
WORKDIR /home/app
USER app

RUN mkdir -p /tmp
COPY --from=gems --chown=app:app /usr/local/bundle /usr/local/bundle

EXPOSE 1234

CMD ["bundle", "exec", "syntropy", "sites"]
