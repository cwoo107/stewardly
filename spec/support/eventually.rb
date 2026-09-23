# expect { value }.to eventually_eq(expected): polls a block for async results (JS system specs).
RSpec::Matchers.define :eventually_eq do |expected|
  supports_block_expectations

  match do |block|
    deadline = Capybara.default_max_wait_time.seconds.from_now
    loop do
      @actual = block.call
      break true if @actual == expected
      break false if Time.current > deadline

      sleep 0.05
    end
  end

  failure_message { "expected #{expected.inspect} within #{Capybara.default_max_wait_time}s, last saw #{@actual.inspect}" }
end
