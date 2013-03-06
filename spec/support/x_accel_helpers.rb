#module XAccelHelpers
  #def x_accel_get(url)
    #get url, nil, {
      #"HTTP_X_SENDFILE_TYPE" => "X-Accel-Redirect",
      #"HTTP_X_ACCEL_MAPPING" => "#{Rails.root}/tmp/test_uploads/assets/=/raw/",
    #}
  #end
#end
#RSpec.configuration.include XAccelHelpers, :type => :request
