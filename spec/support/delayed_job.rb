module DelayedJobHelpers
  def run_all_delayed_jobs
    Delayed::Worker.new(exit_on_complete: true, quiet: true).start
  end

  def most_recently_enqueued_job
    Delayed::Job.asc(:created_at).last
  end

  RSpec::Matchers.define :have_payload do |expected|
    match do |actual|
      expect(actual.payload_object.object).to eq(expected)
    end
  end

  RSpec::Matchers.define :have_method_name do |expected|
    match do |actual|
      expect(actual.payload_object.method_name).to eq(expected)
    end
  end
end

RSpec.configuration.include DelayedJobHelpers, type: :request
