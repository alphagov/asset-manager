object false

node :_response_info do
  { status: "ok" }
end

glue @asset do
  extends "assets/_asset", object: @asset
end
