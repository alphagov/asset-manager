Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Plek.find("whitehall-admin", external: true)

    resource "/media/*",
             headers: :any,
             methods: [:get]
  end
end
