require 'gds-sso/user'

class ReadOnlyUser < OpenStruct
  def self.attr_accessible(*args)
  end

  include GDS::SSO::User

  def self.first
    ReadOnlyUser.new(:permissions => ["signin"])
  end

  def self.find_by_uid(uid)
    nil
  end

  def self.create!(auth_hash, options={})
    ReadOnlyUser.new(auth_hash)
  end

  def update_attribute(*args)
  end
end
