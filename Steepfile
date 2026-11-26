# frozen_string_literal: true

# `bundle exec steep check` type checks lib/ against the signatures in sig/.
target :lib do
  signature 'sig'
  check 'lib'

  configure_code_diagnostics(Steep::Diagnostic::Ruby.strict)
end
