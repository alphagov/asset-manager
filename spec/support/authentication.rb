module AuthenticationControllerHelpers
  def login_as(user)
    request.env['warden'] = stub(
      :authenticate! => true,
      :authenticated? => true,
      :user => user
    )
  end

  def stub_user
    ReadOnlyUser.first
  end

  def login_as_stub_user
    login_as stub_user
  end
end
RSpec.configuration.include AuthenticationControllerHelpers, :type => :controller

module AuthenticationFeatureHelpers
  def login_as(user)
    GDS::SSO.test_user = user
  end

  def stub_user
    ReadOnlyUser.first
  end

  def login_as_stub_user
    login_as stub_user
  end
end
RSpec.configuration.include AuthenticationFeatureHelpers, :type => :request
