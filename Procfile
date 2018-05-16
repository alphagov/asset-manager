web: bundle exec unicorn -c ./config/unicorn.rb -p ${PORT:-3037}
web-upload: bundle exec unicorn -c ./config/unicorn.rb -p ${UPLOAD_PORT:-3039}
worker: bundle exec sidekiq -C ./config/sidekiq.yml
