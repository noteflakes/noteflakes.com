# base image
FROM ruby:3.4.1-alpine AS base
RUN apk add --update sqlite-dev openssl-dev tzdata

# dependencies
FROM base AS dependencies
RUN apk add --update build-base

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs=3 --retry=5

# Final backend image
FROM base
RUN apk add --update bash curl zip git

RUN adduser -D app
RUN chown app:app /home/app
WORKDIR /home/app
USER app

RUN mkdir -p /tmp
COPY --from=dependencies --chown=app:app /usr/local/bundle/ /usr/local/bundle/

EXPOSE 1234

CMD ["bundle", "exec", "ruby", "commands/server.rb"]

