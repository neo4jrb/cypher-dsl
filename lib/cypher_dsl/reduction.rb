# frozen_string_literal: true

module CypherDSL
  # `reduce(accumulator = initial, variable IN list | mapper)`, built step by
  # step: `Cypher.reduce(:n).in(list).map(acc.add(n)).accumulate_on(acc).with_initial_value_of(0)`.
  class Reduction
    include Expression

    attr_reader :variable, :list, :mapper, :accumulator, :initial_value

    def self.of(variable) = Ongoing.new(variable: SymbolicName.of(variable), list: nil, mapper: nil, accumulator: nil)

    def initialize(variable:, list:, mapper:, accumulator:, initial_value:)
      @variable = variable
      @list = list
      @mapper = mapper
      @accumulator = accumulator
      @initial_value = initial_value
      freeze
    end

    # The intermediate states; `with_initial_value_of` completes the reduction.
    Ongoing = Data.define(:variable, :list, :mapper, :accumulator) do
      # @implements Reduction::Ongoing
      def in(list) = with(list: Expression.coerce(list))
      def map(mapper) = with(mapper: Expression.coerce(mapper))
      def accumulate_on(accumulator) = with(accumulator: Expression.coerce(accumulator))

      # The steps are nil until `in`, `map` and `accumulate_on` were called, which Steep cannot see.
      # steep:ignore:start
      def with_initial_value_of(initial_value)
        Reduction.new(variable:, list:, mapper:, accumulator:, initial_value: Expression.coerce(initial_value))
      end
      # steep:ignore:end
    end
  end
end
