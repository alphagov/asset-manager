RSpec::Matchers.define :be_within_a_millisecond_of do |expected|
  match do |actual|
    be_within(0.001).of(expected).matches?(actual)
  end

  failure_message do |actual|
    "expected #{actual.to_f} to be within a millisecond of #{expected.to_f}"
  end

  failure_message_when_negated do |actual|
    "expected #{actual.to_f} not to be within a millisecond of #{expected.to_f}"
  end
end
