# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store,
  key: "_asset_manager_session",
  same_site: :none,
  secure: true,
  httponly: true
