FROM ruby:2.7.2
RUN apt-get update -qq && apt-get upgrade -y && apt-get install -y clamav && apt-get clean
RUN freshclam
RUN ln -sf /usr/bin/clamscan /usr/bin/govuk_clamscan
RUN gem install foreman

# This image is only intended to be able to run this app in a production RAILS_ENV
ENV RAILS_ENV production

ENV GOVUK_APP_NAME asset-manager
ENV GOVUK_ASSET_ROOT http://assets-origin.dev.gov.uk
ENV MONGODB_URI mongodb://mongo/asset-manager
ENV PORT 3037

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle config set deployment 'true'
RUN bundle config set without 'development test'
RUN bundle install --jobs 4
ADD . $APP_HOME

HEALTHCHECK CMD curl --silent --fail localhost:$PORT/healthcheck/ready || exit 1

CMD foreman run web
