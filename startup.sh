#!/bin/bash

bundle install
govuk_setenv asset-manager bundle exec rails s -p 3037
