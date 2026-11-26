# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Rendering options.
    #
    # - `always_escape_names`: backtick-escape labels and relationship types even
    #   when they are plain identifiers, as the Java default renderer does.
    # - `dialect`: one of {Dialect::ALL}.
    # - `pretty_print`: one clause per line, indented subqueries, conditions and maps.
    # - `indent_size` / `indent_style` (`:space` or `:tab`): the indentation unit.
    # - `disable_dynamic_labels`: render label expressions statically even on dialects
    #   that support `n:$($labels)`.
    # - `generated_names`: rewrite names while rendering (`v0`, `v1`, … and `p0`, `p1`, …);
    #   `true` for all of {GENERATED_NAMES}, or a subset of those flags.
    class Configuration
      # The Java `GeneratedNames` enum: which names get rewritten. `reuse_aliases` makes an alias
      # that is defined again reuse its generated name instead of getting a new one.
      GENERATED_NAMES = %i[entity_names parameter_names all_aliases internal_aliases_only reuse_aliases].freeze

      attr_reader :always_escape_names, :dialect, :pretty_print, :indent_size, :indent_style, :disable_dynamic_labels,
                  :generated_names

      # `always_escape_names` defaults to true, except when pretty printing, where
      # names are escaped only when necessary (as upstream does).
      def initialize(always_escape_names: nil, dialect: Dialect::NEO4J_5_DEFAULT_CYPHER, pretty_print: false,
                     indent_size: 2, indent_style: :space, disable_dynamic_labels: false, generated_names: false)
        raise ArgumentError, "Unknown dialect #{dialect.inspect}" unless Dialect::ALL.include?(dialect)
        raise ArgumentError, "Unknown indent style #{indent_style.inspect}" unless %i[space tab].include?(indent_style)

        @always_escape_names = always_escape_names.nil? ? !pretty_print : always_escape_names
        @dialect = dialect
        @pretty_print = pretty_print
        @indent_size = indent_size
        @indent_style = indent_style
        @disable_dynamic_labels = disable_dynamic_labels
        @generated_names = generated_name_flags(generated_names)
        freeze
      end

      def use_generated_names? = !generated_names.empty?

      # Every option by name; configurations with equal options are equal.
      def to_h
        { always_escape_names:, dialect:, pretty_print:, indent_size:, indent_style:, disable_dynamic_labels:,
          generated_names: }
      end

      def ==(other) = other.is_a?(Configuration) && other.to_h == to_h
      alias eql? ==
      def hash = to_h.hash

      # The default configuration, as used by `Statement#cypher`.
      def self.default = @default ||= new

      # Mirrors `Configuration.newConfig()…build()`.
      def self.new_config = Builder.new

      # Mirrors `Configuration.prettyPrinting()`: pretty printed, names escaped only when needed.
      def self.pretty_printing = new(pretty_print: true)

      # `CALL { WITH imports … }` (older dialects) rather than `CALL (imports) { … }`.
      def legacy_subquery_syntax? = Dialect::LEGACY_SUBQUERY_SYNTAX.include?(dialect)

      # `shortestPath()` / `allShortestPaths()` functions rather than `SHORTEST 1` / `ALL SHORTEST` selectors.
      def legacy_path_selectors? = Dialect::LEGACY_PATH_SELECTORS.include?(dialect)

      # `exists(n.prop)` and `distance()` rather than `n.prop IS NOT NULL` and `point.distance()`.
      def legacy_functions? = dialect == Dialect::NEO4J_4

      # `n:$($labels)` is available and wanted.
      def dynamic_labels? = Dialect::DYNAMIC_LABELS.include?(dialect) && !disable_dynamic_labels

      # The `CYPHER 5 ` / `CYPHER 25 ` statement prefix of the dialect, if any.
      def prefix = Dialect::PREFIXES[dialect]

      def indent_unit = indent_style == :tab ? "\t" : ' ' * indent_size

      # Fluent builder; each setter returns the builder.
      class Builder
        def initialize
          @options = {}
        end

        def always_escape_names(value) = option(:always_escape_names, value)
        def with_dialect(dialect) = option(:dialect, dialect)
        def with_pretty_print(value) = option(:pretty_print, value)
        def with_indent_size(size) = option(:indent_size, size)
        def with_indent_style(style) = option(:indent_style, style)

        def disable_dynamic_labels(value = true) # rubocop:disable Style/OptionalBooleanParameter -- Java signature
          option(:disable_dynamic_labels, value)
        end

        # `true`, `false` or a list of {Configuration::GENERATED_NAMES} flags.
        def with_generated_names(value) = option(:generated_names, value)

        def build = Configuration.new(**@options)

        private

        def option(name, value)
          @options[name] = value
          self
        end
      end

      private

      def generated_name_flags(value)
        flags = case value
                when true then GENERATED_NAMES
                when false, nil then [] # steep:ignore UnannotatedEmptyCollection
                else value.to_a.map(&:to_sym)
                end
        unknown = flags - GENERATED_NAMES
        raise ArgumentError, "Unknown generated name flags #{unknown.inspect}" unless unknown.empty?

        flags.to_set.freeze #: Set[generated_name]
      end
    end
  end
end
