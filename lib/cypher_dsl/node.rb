# frozen_string_literal: true

module CypherDSL
  # A node pattern `(name:Label {props} WHERE condition)`. Used as an expression
  # it stands for its symbolic name.
  #
  # Nodes are value objects; the one piece of lazily computed state is the
  # generated name an unnamed node receives when something references it, as
  # in the Java `getRequiredSymbolicName`.
  class Node
    include Expression

    attr_reader :labels, :properties, :where_condition

    # The explicit name, or the generated one once {#required_symbolic_name} was called.
    attr_reader :symbolic_name

    def initialize(labels:, symbolic_name: nil, properties: nil, where_condition: nil)
      @labels = labels.freeze
      @symbolic_name = symbolic_name
      @properties = properties
      @where_condition = where_condition
    end

    def named(name) = with(symbolic_name: SymbolicName.of(name))

    def with_properties(*keys_and_values) = with(properties: MapExpression.of(*keys_and_values))

    # The inline predicate `(n WHERE condition)`.
    def where(condition) = with(where_condition: Condition.coerce(condition))

    def named? = !@symbolic_name.nil?

    # The name of this node, generating one if it has none (and keeping it, as in Java).
    def required_symbolic_name
      @symbolic_name ||= SymbolicName.unresolved(name_hint) # rubocop:disable Naming/MemoizedInstanceVariableName
    end

    # The first plain label, lower-cased, or `n` for nodes without one.
    def name_hint = labels.first.then { it.is_a?(String) ? it.downcase : 'n' }
    alias as_expression required_symbolic_name

    # `n.prop`; the property keeps this node as its container (index hints need the label),
    # the name is settled now so generated names keep their order.
    def property(*names)
      required_symbolic_name
      Property.new(self, names)
    end

    # The condition `n:Label`, checking the node for the given labels.
    def has_labels(*labels) = HasLabelCondition.new(self, labels)

    # `n += {…}` and `n = {…}`, for use in SET; the node must be named.
    def mutate(expression) = Operation.new(named_for_update, '+=', Expression.coerce(expression))
    def set(expression) = Operation.new(named_for_update, '=', Expression.coerce(expression))

    # The map projection `n{…}`, built on the (possibly generated) name.
    def project(*entries) = MapProjection.new(required_symbolic_name, entries.flatten)

    # `id(n)`; deprecated in Neo4j 5 in favour of {#element_id}, kept for parity.
    def internal_id = FunctionInvocation.new('id', [required_symbolic_name])

    # `labels(n)`.
    def labels_function = FunctionInvocation.new('labels', [required_symbolic_name])

    # `elementId(n)`.
    def element_id = FunctionInvocation.new('elementId', [required_symbolic_name])

    def relationship_to(other, *types) = Relationship.create(self, :ltr, other, types)
    def relationship_from(other, *types) = Relationship.create(self, :rtl, other, types)
    def relationship_between(other, *types) = Relationship.create(self, :uni, other, types)

    # `relationship_with(other, Relationship::Direction::LTR, 'TYPE')`: the direction as a value.
    def relationship_with(other, direction, *types)
      unless Relationship::Direction::ALL.include?(direction)
        raise ArgumentError, "Unknown direction #{direction.inspect}, use one of Relationship::Direction"
      end

      Relationship.create(self, direction, other, types)
    end

    private

    def named_for_update
      raise ArgumentError, 'A property container must be named to be mutated.' unless named?

      self
    end

    def with(**changes)
      Node.new(labels:, symbolic_name: @symbolic_name, properties:, where_condition:, **changes)
    end
  end
end
