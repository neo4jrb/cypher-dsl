# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake'
gem 'rspec', '~> 3.13'

# Static checks (see CONTRIBUTING.md). RuboCop and Reek are pinned to the patch
# level: a minor bump can add cops or detectors and turn CI red, so bump them
# deliberately and refresh the baselines.
gem 'reek', '~> 6.6.0', require: false
gem 'rubocop', '~> 1.92.0', require: false
gem 'rubocop-performance', '~> 1.27.0', require: false
gem 'rubocop-rspec', '~> 3.10.0', require: false

# Coverage and type checking run on MRI only.
platforms :ruby do
  gem 'rbs', require: false
  gem 'simplecov', require: false
  gem 'steep', require: false
end
