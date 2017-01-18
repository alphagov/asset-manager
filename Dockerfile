FROM ruby:2.2.3
RUN apt-get update -qq && apt-get upgrade -y && apt-get clean

ENV PORT 3037
ENV MONGODB_URI mongodb://mongo/asset-manager-development
ENV TEST_MONGODB_URI mongodb://mongo/asset-manager-test

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

CMD bash -c "rm -f tmp/pids/server.pid && bundle exec rails s -p $PORT -b '0.0.0.0'"
