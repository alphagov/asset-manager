FROM ruby:2.6.5
RUN apt-get update -qq && apt-get upgrade -y && apt-get install -y clamav && apt-get clean
RUN freshclam
RUN ln -sf /usr/bin/clamscan /usr/bin/govuk_clamscan
RUN gem install foreman

ENV GOVUK_APP_NAME asset-manager
ENV GOVUK_ASSET_ROOT http://assets-origin.dev.gov.uk
ENV MONGODB_URI mongodb://mongo/asset-manager
ENV PORT 3037
ENV REDIS_HOST redis
ENV TEST_MONGODB_URI mongodb://mongo/asset-manager-test

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

HEALTHCHECK CMD curl --silent --fail localhost:$PORT/healthcheck || exit 1

CMD foreman run web
