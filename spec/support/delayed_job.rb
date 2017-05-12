module DelayedJobHelpers
  def run_all_delayed_jobs
    Delayed::Worker.new(:exit_on_complete => true, :quiet => false).start
  end
end

RSpec.configuration.include DelayedJobHelpers, :type => :request
