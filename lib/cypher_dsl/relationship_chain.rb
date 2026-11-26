# frozen_string_literal: true

module CypherDSL
  # A chain of relationships sharing nodes, `(a)-[]->(b)-[]->(c)`. Modifiers
  # such as `named`, `min` or `properties` apply to the last relationship.
  class RelationshipChain
    attr_reader :relationships

    def initialize(relationships)
      @relationships = relationships.freeze
      freeze
    end

    def relationship_to(other, *types) = add(:ltr, other, types)
    def relationship_from(other, *types) = add(:rtl, other, types)
    def relationship_between(other, *types) = add(:uni, other, types)

    def named(name) = update_last { |relationship| relationship.named(name) }
    def with_properties(*keys_and_values) = update_last { it.with_properties(*keys_and_values) }
    alias properties with_properties
    def min(minimum) = update_last { |relationship| relationship.min(minimum) }
    def max(maximum) = update_last { |relationship| relationship.max(maximum) }
    def length(minimum, maximum) = update_last { |relationship| relationship.length(minimum, maximum) }
    def unbounded = update_last(&:unbounded)
    def where(condition) = update_last { |relationship| relationship.where(condition) }
    def quantify_relationship(quantifier) = update_last { it.quantify_relationship(quantifier) }

    # `((a)-[]->(b)-[]->(c)){1,3}`: a quantifier on the whole chain.
    def quantify(quantifier) = QuantifiedPathPattern.new(self, quantifier)

    # The chain as a predicate.
    def as_condition = RelationshipPatternCondition.new(self)

    # The pattern as Cypher, names escaped only when necessary.
    def to_s = Renderer.plain.render_fragment(self)

    private

    def add(direction, other, types)
      RelationshipChain.new(relationships + [Relationship.create(relationships.last.right, direction, other, types)])
    end

    def update_last
      head = relationships[0...-1] #: Array[Relationship]
      RelationshipChain.new(head + [yield(relationships.last)])
    end
  end
end
