AssetManager::Application.routes.draw do

  # Temporary dummy route to keep healthcheck happy
  root :to => lambda {|*args| [200, {}, ["Hello"]]}
end
