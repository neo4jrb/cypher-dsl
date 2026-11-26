# frozen_string_literal: true

module CypherDSL
  # A whole path pattern with a quantifier, `((a)-[:X]->(b)){1,3}`, optionally
  # with an inline WHERE. Built with `relationship.quantify(quantifier)`.
  #
  # Quantifiers come from {.interval}, {.plus} and {.star}; a relationship-only
  # quantifier (`-[:X]->{1,3}`) is applied with `quantify_relationship`.
  class QuantifiedPathPattern
    # `{lower,upper}`, `+` or `*`.
    Quantifier = Data.define(:lower, :upper, :symbol) do
      # @implements QuantifiedPathPattern::Quantifier
      def to_cypher = symbol || "{#{lower || 0},#{upper}}"
    end

    def self.interval(lower, upper)
      raise ArgumentError, 'Lower bound must be greater than or equal to zero' if lower&.negative?
      raise ArgumentError, 'Upper bound must be greater than zero' if upper && upper < 1
      raise ArgumentError, "Upper bound must be greater than or equal to #{lower}" if lower && upper && upper < lower

      Quantifier.new(lower:, upper:, symbol: nil)
    end

    def self.plus = Quantifier.new(lower: 1, upper: nil, symbol: '+')
    def self.star = Quantifier.new(lower: 0, upper: nil, symbol: '*')

    attr_reader :pattern, :quantifier, :where_condition

    def initialize(pattern, quantifier, where_condition: nil)
      @pattern = pattern
      @quantifier = quantifier
      @where_condition = where_condition
      freeze
    end

    def where(condition) = QuantifiedPathPattern.new(pattern, quantifier, where_condition: Condition.coerce(condition))
  end
end
