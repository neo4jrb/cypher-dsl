# frozen_string_literal: true

module CypherDSL
  # A planner hint on a MATCH clause: `USING INDEX [SEEK] n:Label(prop, …)`,
  # `USING SCAN n:Label` or `USING JOIN ON n, m`.
  class Hint
    attr_reader :type, :container, :schema_name, :property_names, :names

    # `use_index_for(seek, *properties)`: all properties must belong to the same node or relationship.
    def self.use_index_for(seek, *properties)
      properties = properties.flatten
      raise ArgumentError, 'Cannot use an index without properties!' if properties.empty?

      references = properties.map { |property| index_reference(property) }
      if references.map(&:first).uniq.size > 1
        raise ArgumentError, 'If you want to use more than one index on different nodes you must use multiple ' \
                             '`USING INDEX` statements.'
      end

      container, schema_name = references.first
      new(seek ? :index_seek : :index, container:, schema_name:, property_names: properties.map { |p| p.names.first })
    end

    def self.use_scan_for(node)
      raise ArgumentError, 'Cannot apply a SCAN hint without a node.' if node.nil?
      raise ArgumentError, 'Exactly one label is required for a SCAN hint.' unless node.labels.size == 1

      new(:scan, container: node, schema_name: node.labels.first)
    end

    def self.use_join_on(*nodes_or_names)
      nodes_or_names = nodes_or_names.flatten
      raise ArgumentError, 'At least one node is required to define a JOIN hint.' if nodes_or_names.empty?

      names = nodes_or_names.map do |item|
        item.respond_to?(:required_symbolic_name) ? item.required_symbolic_name : SymbolicName.of(item)
      end
      new(:join, names:)
    end

    # The container and its single label or type, validated for an index hint.
    def self.index_reference(property)
      container = property.container
      unless container.is_a?(Node) || container.is_a?(Relationship)
        raise ArgumentError, 'Cannot use a property without a reference to a container inside an index hint.'
      end
      raise ArgumentError, 'One single property is required. Nested properties are not supported.' if property.nested?

      if container.is_a?(Node)
        raise ArgumentError, 'Exactly one label is required to define the index.' unless container.labels.size == 1

        [container, container.labels.first]
      else
        types = container.details.types
        raise ArgumentError, 'Exactly one type is required to define the index.' unless types.size == 1

        [container, types.first]
      end
    end
    private_class_method :index_reference

    def initialize(type, container: nil, schema_name: nil, property_names: [], names: [])
      @type = type
      @container = container
      @schema_name = schema_name #: String?
      @property_names = property_names.freeze
      @names = names.freeze
      freeze
    end
  end
end
