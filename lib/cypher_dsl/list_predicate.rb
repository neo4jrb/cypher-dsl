# frozen_string_literal: true

module CypherDSL
  # The list predicates `all(x IN list WHERE condition)`, `any(…)`, `none(…)`, `single(…)`.
  # Built with `Cypher.all(:x).in(list).where(condition)` (or `any`, `none`, `single`).
  class ListPredicate < Condition
    attr_reader :predicate, :variable, :list, :condition

    def initialize(predicate, variable, list, condition)
      super()
      @predicate = predicate
      @variable = SymbolicName.of(variable)
      @list = list
      @condition = condition
      freeze
    end

    # `Cypher.all(:x)`: waiting for `in(list)` and then `where(condition)`.
    class Ongoing
      def initialize(predicate, variable, list = nil)
        @predicate = predicate
        @variable = variable
        @list = list
        freeze
      end

      def in(list) = Ongoing.new(@predicate, @variable, Expression.coerce(list))

      # `where` needs an `in` first; Steep cannot see that `@list` is set by then.
      # steep:ignore:start
      def where(condition) = ListPredicate.new(@predicate, @variable, @list, Condition.coerce(condition))
      # steep:ignore:end
    end
  end
end
