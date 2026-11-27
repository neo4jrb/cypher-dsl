# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run Reek against the .reek.yml baseline'
task(:reek) { sh 'bundle exec reek lib' }

desc 'Validate the RBS signatures in sig/'
task(:rbs) { sh 'bundle exec rbs -I sig validate' }

desc 'Type check lib/ against sig/ with Steep'
task(:steep) { sh 'bundle exec steep check' }

# rbs and steep are MRI-only in the Gemfile (`platforms :ruby`), so JRuby runs the rest.
TYPE_CHECKS = RUBY_ENGINE == 'jruby' ? [] : %i[rbs steep]

desc 'All static checks: rubocop, reek, rbs, steep (rbs and steep on MRI only)'
task static: %i[rubocop reek] + TYPE_CHECKS

namespace :coverage do
  # Fail if any line added/modified since BASE (default origin/main) under lib/
  # is executable, was loaded by the test run, and went uncovered. Reads every
  # coverage/**/.resultset.json produced by `COVERAGE=1 rspec` and unions them.
  desc 'Enforce 100% coverage on lines changed vs BASE (default origin/main)'
  task :enforce, [:base] do |_task, args|
    require_relative 'tasks/diff_coverage'
    root = __dir__
    base = args[:base] || ENV['COVERAGE_BASE'] || 'origin/main'
    resultsets = Dir[File.join(root, 'coverage/**/.resultset.json')]
    raise 'No coverage resultsets found. Run `COVERAGE=1 bundle exec rspec` first.' if resultsets.empty?

    changed = DiffCoverage.changed_lines(base: base, root: root)
    violations = DiffCoverage.new(root: root, resultset_paths: resultsets, changed_lines: changed).violations
    changed_count = changed.values.sum(&:size)

    if violations.empty?
      puts "Diff coverage OK: #{changed_count} changed line(s) across #{changed.size} file(s), " \
           "all covered (base #{base}, #{resultsets.size} resultset(s))."
    else
      warn "Uncovered changed lines (#{violations.size} of #{changed_count} changed):"
      violations.each { |v| warn "  #{v.path}:#{v.line}" }
      abort 'Diff coverage failed: every new or changed line must be covered by a test.'
    end
  end
end

task default: %i[spec static]
