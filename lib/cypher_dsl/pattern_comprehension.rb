# frozen_string_literal: true

module CypherDSL
  # `[pattern WHERE condition | expression]`. Built with `Cypher.list_based_on(pattern)`,
  # refined with `where`/`and`/`or`, completed with `returning`.
  class PatternComprehension
    include Expression

    attr_reader :pattern, :where_condition, :projection

    def initialize(pattern, where_condition: nil, projection: nil)
      @pattern = pattern
      @where_condition = where_condition
      @projection = projection&.freeze
      freeze
    end

    def where(condition) = with(where_condition: Condition.coerce(condition))

    # `and` and `or` need a `where` first; Steep cannot see that `where_condition` is set by then.
    def and(condition) = with(where_condition: where_condition.and(condition)) # steep:ignore NoMethod
    def or(condition) = with(where_condition: where_condition.or(condition)) # steep:ignore NoMethod

    def returning(*expressions) = with(projection: expressions.flatten.map { |e| Expression.coerce(e) })

    private

    def with(**changes)
      PatternComprehension.new(pattern, where_condition:, projection:, **changes)
    end
  end
end
