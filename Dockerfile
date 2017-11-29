FROM ruby:2.4.2
RUN apt-get update -qq && apt-get upgrade -y && apt-get install -y clamav && apt-get clean
RUN freshclam
RUN ln -sf /usr/bin/clamscan /usr/bin/govuk_clamscan
RUN gem install bundler -v1.14.5

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

CMD bash -c "rm -f tmp/pids/server.pid && bundle exec rails s -p $PORT -b '0.0.0.0'"
