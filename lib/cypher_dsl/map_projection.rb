# frozen_string_literal: true

module CypherDSL
  # A map projection `n{.name, .age, total: count(x), .*}`.
  #
  # Entries follow the Java rules: a name followed by an expression is a
  # `key: expression` pair, a lone name is a property lookup `.name`, an
  # expression on its own is rendered as is, and `Cypher.asterisk` is `.*`.
  class MapProjection
    include Expression

    attr_reader :subject, :entries

    def initialize(subject, entries)
      @subject = subject
      @entries = MapProjection.parse(entries).freeze
      freeze
    end

    def and(*more_entries) = MapProjection.new(subject, entries + more_entries.flatten)

    # Entries already parsed (arrays, from `and`) pass through untouched.
    def self.parse(raw_entries)
      # @type var entries: Array[entry]
      entries = []
      # @type var pending_key: String?
      pending_key = nil
      raw_entries.each do |entry|
        if pending_key
          entries << (name?(entry) ? [:lookup, pending_key] : [:pair, pending_key, Expression.coerce(entry)])
          pending_key = name?(entry) ? entry.to_s : nil
        elsif name?(entry)
          pending_key = entry.to_s
        else
          entries << parse_expression(entry)
        end
      end
      entries << [:lookup, pending_key] if pending_key
      entries
    end

    def self.parse_expression(entry)
      case entry
      when Array then entry # already parsed (from `and`)
      when Asterisk then [:all]
      when Property
        raise ArgumentError, 'Cannot project nested properties!' if entry.nested?

        [:property, entry]
      when AliasedExpression then [:pair, entry.alias_name.value, entry]
      when SymbolicName, Node, Relationship then [:expression, entry]
      else
        raise ArgumentError,
              "#{entry.inspect} of type #{entry.class} cannot be used with an implicit name as map entry."
      end
    end

    def self.name?(entry) = entry.is_a?(String) || entry.is_a?(Symbol)
  end
end
