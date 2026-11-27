# frozen_string_literal: true

target :lib do
  signature 'sig'
  check 'lib'
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end

# Public API calls that must type check; see typecheck/usage.rb.
target :usage do
  signature 'sig'
  check 'typecheck'
  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
