# frozen_string_literal: true

module CypherDSL
  # `Cypher.using_periodic_commit(500).load_csv(uri).as(:line)`: the legacy
  # `USING PERIODIC COMMIT [rate]` prefix of a LOAD CSV statement.
  UsingPeriodicCommit = Data.define(:rate) do
    # @implements UsingPeriodicCommit
    def load_csv(uri, positional_headers = false, with_headers: positional_headers) # rubocop:disable Style/OptionalBooleanParameter
      StatementBuilder.new.load_csv(uri, with_headers:, periodic_commit: rate || true)
    end
  end
end
