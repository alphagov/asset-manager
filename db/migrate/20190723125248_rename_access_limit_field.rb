class RenameAccessLimitField < Mongoid::Migration
  def self.up
    Asset.all.rename(title: 'access_limited', name: 'access_limited_user_ids')
  end

  def self.down
    Asset.all.rename(title: 'access_limited_user_ids', name: 'access_limited')
  end
end
