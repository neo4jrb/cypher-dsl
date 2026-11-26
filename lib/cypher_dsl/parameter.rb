# frozen_string_literal: true

module CypherDSL
  # A query parameter, rendered as `$name`, optionally carrying its value.
  # An anonymous parameter has no name of its own; the renderer assigns
  # `pcdsl01`, `pcdsl02`, … per statement, sharing a name between anonymous
  # parameters with equal values.
  class Parameter
    include Expression

    NO_VALUE = Object.new.freeze

    attr_reader :name, :value

    def self.anonymous(value) = new(nil, value)

    # A leading `$` in the name is tolerated and dropped.
    def initialize(name, value = NO_VALUE)
      @name = name&.to_s&.delete_prefix('$')
      # Steep does not narrow instance variables.
      raise ArgumentError, 'A parameter name must not be empty.' if @name && @name.empty? # steep:ignore NoMethod

      @value = value
      freeze
    end

    def with_value(value) = Parameter.new(name, value)

    def anonymous? = name.nil?
    def value? = !value.equal?(NO_VALUE)

    # Named parameters are equal by name and value, anonymous ones by value.
    def ==(other)
      other.is_a?(Parameter) && other.name == name && other.value == value
    end
    alias eql? ==
    def hash = [self.class, name, value].hash

    def to_s = "$#{Renderer::Escaper.escape_parameter_name(name || '?')}"
  end
end
