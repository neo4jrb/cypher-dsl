# frozen_string_literal: true

module CypherDSL
  # A fragment of Cypher text rendered verbatim: the escape hatch, like `Arel.sql`.
  #
  # `RawExpression.create(format, *arguments)` mirrors `Cypher.raw(format, args…)`:
  # every `$E` in the format is replaced by the next argument (expressions as they are,
  # anything else as a literal); `\$E` stands for a literal `$E`. A `$name` matching a
  # named parameter among the arguments is bound to that parameter.
  class RawExpression
    include Expression

    PLACEHOLDER = /((\\?\$(\w+))(?:\s*|$))/
    EXPRESSION_PLACEHOLDER = '$E'
    private_constant :PLACEHOLDER, :EXPRESSION_PLACEHOLDER

    # Strings and expressions, in order.
    attr_reader :parts

    def self.create(format, *mixed_arguments)
      raise ArgumentError, 'Cannot create a raw literal without a format.' if format.nil? || format.strip.empty?

      new(Parser.new(format, mixed_arguments).parts)
    end

    # `parts` is a string or a list of strings and expressions.
    def initialize(parts)
      @parts = Array(parts).filter_map do |part|
        next part unless part.is_a?(String) # steep:ignore BreakTypeMismatch

        part.gsub('\$E', EXPRESSION_PLACEHOLDER) unless part.empty?
      end.freeze
      freeze
    end

    # The text, with expressions in their default rendering.
    def content = parts.join

    # Splits a format into text and the expressions bound to its placeholders.
    class Parser
      def initialize(format, mixed_arguments)
        @format = format
        @parameters = mixed_arguments.grep(Parameter).reject(&:anonymous?).to_h { |p| [p.name, p] }
        @positional = mixed_arguments.dup
        # `last_match` is never `nil` right after a `scan` match, which Steep cannot see.
        @matches = format.enum_for(:scan, PLACEHOLDER).map { Regexp.last_match } # steep:ignore BlockBodyTypeMismatch
        # Placeholders naming an actual parameter take it with precedence over the positional ones.
        @matches.each { |match| @positional.delete(@parameters[match[3]]) if @parameters.key?(match[3]) }
        @parts = []
        @index = 0
        @count = 0
      end

      def parts
        @matches.each { |match| consume(match) }
        raise ArgumentError, "Too many arguments for the raw literal format `#{@format}`." if @count < @positional.size

        @parts + [@format[@index..]]
      end

      private

      def consume(match)
        if match[2] == EXPRESSION_PLACEHOLDER
          bind(match, next_positional)
        elsif @parameters.key?(match[3])
          bind(match, @parameters[match[3]])
        else
          @parts << @format[@index...match.end(0)]
          @index = match.end(0)
        end
      end

      def bind(match, expression)
        @parts << @format[@index...match.begin(2)] << expression
        @index = match.end(2)
      end

      def next_positional
        raise ArgumentError, "Too few arguments for the raw literal format `#{@format}`." if @count >= @positional.size

        argument = @positional[@count]
        @count += 1
        Expression.coerce(argument)
      end
    end
    private_constant :Parser
  end
end
