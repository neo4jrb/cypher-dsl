# frozen_string_literal: true

module CypherDSL
  # A relationship pattern between two nodes, `(a)-[r:TYPE*1..3 {props} WHERE …]->{1,3}(b)`.
  # Used as an expression it stands for its symbolic name.
  class Relationship
    include Expression

    # Everything between the brackets plus the direction and a relationship quantifier.
    Details = Data.define(:types, :symbolic_name, :properties, :min, :max, :unbounded, :where, :quantifier) do
      # @implements Relationship::Details
      def empty?
        symbolic_name.nil? && types.empty? && properties.nil? && !length? && where.nil?
      end

      def length? = unbounded || !min.nil? || !max.nil?
    end

    # The direction of a relationship pattern, for {Node#relationship_with}.
    module Direction
      LTR = :ltr
      RTL = :rtl
      UNI = :uni
      ALL = [LTR, RTL, UNI].freeze
    end

    attr_reader :left, :right, :direction, :details

    def self.create(left, direction, right, types)
      details = Details.new(types: types.map(&:to_s).freeze, symbolic_name: nil, properties: nil,
                            min: nil, max: nil, unbounded: false, where: nil, quantifier: nil)
      new(left, direction, right, details)
    end

    def initialize(left, direction, right, details)
      raise ArgumentError, 'Left node is required.' if left.nil?
      raise ArgumentError, 'Right node is required.' if right.nil?

      @left = left
      @direction = direction
      @right = right
      @details = details
      @generated_name = nil
    end

    # The explicit name, or the generated one once {#required_symbolic_name} was called.
    def symbolic_name = details.symbolic_name || @generated_name

    def named? = !symbolic_name.nil?

    # The name of this relationship, generating one if it has none.
    def required_symbolic_name = details.symbolic_name || generated_name
    alias as_expression required_symbolic_name

    def named(name) = with_details(symbolic_name: SymbolicName.of(name))

    def with_properties(*keys_and_values) = with_details(properties: MapExpression.of(*keys_and_values))
    alias properties with_properties

    def min(minimum) = with_details(min: minimum)
    def max(maximum) = with_details(max: maximum)
    def length(minimum, maximum) = with_details(min: minimum, max: maximum)
    def unbounded = with_details(unbounded: true)

    # The inline predicate `-[r WHERE condition]->`.
    def where(condition) = with_details(where: Condition.coerce(condition))

    # `-[:X]->{1,3}`: a quantifier on the relationship only.
    def quantify_relationship(quantifier) = with_details(quantifier:)

    # `((a)-[:X]->(b)){1,3}`: a quantifier on the whole pattern.
    def quantify(quantifier) = QuantifiedPathPattern.new(self, quantifier)

    # The pattern as a predicate, `WHERE (a)-[:X]->(b)`.
    def as_condition = RelationshipPatternCondition.new(self)

    # `r.prop`; the property keeps this relationship as its container (index hints need the type).
    def property(*names)
      required_symbolic_name
      Property.new(self, names)
    end

    # `r += {…}` and `r = {…}`, for use in SET.
    def mutate(expression) = Operation.new(self, '+=', Expression.coerce(expression))
    def set(expression) = Operation.new(self, '=', Expression.coerce(expression))

    # The map projection `r{…}`, built on the (possibly generated) name.
    def project(*entries) = MapProjection.new(required_symbolic_name, entries.flatten)

    # `elementId(r)`.
    def element_id = FunctionInvocation.new('elementId', [required_symbolic_name])

    def relationship_to(other, *types) = RelationshipChain.new([self]).relationship_to(other, *types)
    def relationship_from(other, *types) = RelationshipChain.new([self]).relationship_from(other, *types)
    def relationship_between(other, *types) = RelationshipChain.new([self]).relationship_between(other, *types)

    private

    def generated_name = @generated_name ||= SymbolicName.unresolved(details.types.first&.downcase || 'r')

    def with_details(**changes)
      Relationship.new(left, direction, right, details.with(**changes))
    end
  end
end
