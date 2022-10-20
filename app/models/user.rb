require "gds-sso/user"

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include GDS::SSO::User

  field "name",    type: String
  field "uid",     type: String
  field "version", type: Integer
  field "email",   type: String
  field "permissions", type: Array
  field "remotely_signed_out", type: Boolean, default: false
  field "disabled", type: Boolean, default: false
  field "organisation_content_id", type: String
  field "organisation_slug", type: String

  def self.find_by_email(email)
    where(email:).first
  end

  def self.find_by_uid(uid)
    where(uid:).first
  end
end
