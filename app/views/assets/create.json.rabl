object false

node :_response_info do
  { status: "created" }
end

glue @asset do
  extends "assets/_asset", object: @asset
end
