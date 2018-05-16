web: bundle exec unicorn -c ./config/unicorn.rb -p ${PORT:-3037}
web-uploads: bundle exec unicorn -c ./config/unicorn.rb -p ${UPLOADS_PORT:-3037}
worker: bundle exec sidekiq -C ./config/sidekiq.yml
