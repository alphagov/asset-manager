require "csv"

namespace :export do
  desc "Export CSV of mirrorable (publicly visible, non-replaced, non-redirected) assets"
  task :mirrorable do
    params = {
      deleted_at: nil,
      replacement_id: nil,
      redirect_url: nil,
      :draft.in => [nil, false],
    }

    CSV.open("mirrorable.csv", "wb") do |csv|
      csv << %w[uuid public_url_path]
      Asset.where(params).each do |asset|
        csv << [asset.uuid, asset.public_url_path]
      end
    end
  end
end
