# frozen_string_literal: true

module CypherDSL
  module Clauses
    # `[USING PERIODIC COMMIT [rate]] LOAD CSV [WITH HEADERS] FROM 'uri' AS alias [FIELDTERMINATOR ';']`.
    # `periodic_commit` is nil, `true` or the commit rate.
    LoadCsv = Data.define(:uri, :with_headers, :alias_name, :field_terminator, :periodic_commit) do
      # @implements Clauses::LoadCsv
      # A blank terminator leaves the clause as it is.
      def with_field_terminator(terminator)
        terminator.nil? || terminator.strip.empty? ? self : with(field_terminator: terminator)
      end
    end
  end
end
