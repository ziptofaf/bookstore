# syntax=docker/dockerfile:1
# Image for running the app locally with `docker compose up` (development environment:
# verbose logs, mailer previews, no credentials needed). Not tuned for production.

ARG RUBY_VERSION=3.4.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libpq-dev libyaml-dev pkg-config postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle"

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
