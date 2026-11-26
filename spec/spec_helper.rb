# frozen_string_literal: true

# Coverage is opt-in (COVERAGE=1) so the normal run is unaffected, and MRI only.
# It must start before cypher_dsl is required so every lib file is tracked;
# `rake coverage:enforce` gates the changed lines of a PR on the result.
if !ENV['COVERAGE'].to_s.empty? && RUBY_PLATFORM != 'java'
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch
    add_filter %r{^/spec/}
  end
end

require 'cypher_dsl'

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
