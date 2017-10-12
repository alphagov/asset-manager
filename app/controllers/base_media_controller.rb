class BaseMediaController < ApplicationController
  skip_before_filter :require_signin_permission!
end
