#FROM ruby:2.5.1-alpine AS build-env
FROM ruby:2.7.0-alpine3.10 AS build-env

ARG RAILS_ROOT=/app
ARG BUILD_PACKAGES="build-base curl-dev git"
ARG DEV_PACKAGES="postgresql-dev yaml-dev zlib-dev nodejs yarn"
#ARG BUILD_PACKAGES="build-essential curl git-core"
#ARG DEV_PACKAGES="libyaml-dev zlib1g-dev nodejs yarn"
ARG RUBY_PACKAGES="tzdata"

#ENV RAILS_ENV=production
#ENV NODE_ENV=production
ENV RAILS_ENV=development
ENV NODE_ENV=development
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"
ENV RUBY_VER=2.7.0

WORKDIR $RAILS_ROOT

# install packages
RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $BUILD_PACKAGES $DEV_PACKAGES $RUBY_PACKAGES

COPY Gemfile* package.json yarn.lock ./
# install rubygem
COPY Gemfile Gemfile.lock $RAILS_ROOT/

RUN gem install bundler \
    && bundler config --global frozen 1
RUN ls -al /app
# RUN bundle install --without development:test:assets -j4 --retry 3 --path=vendor/bundle \
RUN bundle config set without 'development:test:assets'
RUN bundle install -j4 --retry 3 --path=vendor/bundle \
    # Remove unneeded files (cached *.gem, *.o, *.c)
    && rm -rf vendor/bundle/ruby/$RUBY_VER/cache/*.gem \
    && find vendor/bundle/ruby/$RUBY_VER/gems/ -name "*.c" -delete \
    && find vendor/bundle/ruby/$RUBY_VER/gems/ -name "*.o" -delete

RUN yarn install --production
COPY . .
RUN ls -alrt bin/
RUN bin/rails webpacker:compile
RUN bin/rails assets:precompile

# Remove folders not needed in resulting image
RUN rm -rf node_modules tmp/cache app/assets vendor/assets spec

############### Build step done ###############

#FROM ruby:2.5.1-alpine
FROM ruby:2.7.0-alpine3.10
ARG RAILS_ROOT=/app
ARG PACKAGES="tzdata postgresql-client nodejs bash"

#ENV RAILS_ENV=production
ENV RAILS_ENV=development
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"

WORKDIR $RAILS_ROOT

# install packages
RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $PACKAGES

COPY --from=build-env $RAILS_ROOT $RAILS_ROOT
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]