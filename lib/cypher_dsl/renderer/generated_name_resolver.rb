# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Rewrites names to `v0`, `v1`, … per scope and parameters to `p0`, `p1`, …,
    # controlled by the flags of `Configuration::GENERATED_NAMES` (the Java
    # `GeneratedNames` enum).
    class GeneratedNameResolver < NameResolver
      def initialize(flags)
        super()
        @flags = flags.to_set
        @parameter_count = 0
        @counters = []
        @lookups = []
        @used = []
        enter_scope([])
      end

      # `imports` are the identifiables visible inside the new scope, or `:all`.
      def enter_scope(imports)
        outer = @lookups.last #: Hash[lookup_key, String]
        lookup = {} #: Hash[lookup_key, String]
        used = Set.new
        if outer
          lookup = imports == :all ? outer.dup : imports.to_h { |import| [key_of(import), outer[key_of(import)]] }
          lookup.compact!
          used.merge(outer.values)
        end
        @counters << 0
        @lookups << lookup
        @used << used
      end

      # `exports` are the identifiables the scope returns to its outer scope, or `:all`.
      def leave_scope(exports)
        @counters.pop
        inner = @lookups.pop #: Hash[lookup_key, String]
        @used.pop
        outer = @lookups.last #: Hash[lookup_key, String]
        if exports == :all
          outer.merge!(inner)
        else
          exports.each { |export| outer[key_of(export)] = exported_name(export, inner) }
        end
        @used.last.merge(inner.values)
      end

      def resolve(symbolic_name, in_entity: false)
        key = key_of(symbolic_name)
        lookup = @lookups.last
        if !flag?(:entity_names) || (!in_entity && !flag?(:all_aliases) && !flag?(:internal_aliases_only))
          return lookup[key] if lookup.key?(key)

          return super
        end

        lookup[key] ||= new_name
      end

      def resolve_alias(aliased, define: false, in_last_return: false)
        return super unless flag?(:all_aliases) || (flag?(:internal_aliases_only) && !in_last_return)

        key = key_of(aliased)
        lookup = @lookups.last
        return lookup[key] ||= new_name if flag?(:reuse_aliases)
        return lookup.fetch(key) { super } unless define

        lookup[key] = new_name
      end

      def resolve_parameter(parameter)
        return super if !flag?(:parameter_names) || parameter.anonymous?

        @lookups.last[[:parameter, parameter.name]] ||= begin
          name = "p#{@parameter_count}"
          @parameter_count += 1
          name
        end
      end

      private

      def flag?(flag) = @flags.include?(flag)

      def key_of(object)
        case object
        when AliasedExpression then object.alias_name
        when Node, Relationship then object.required_symbolic_name
        else object
        end
      end

      def exported_name(export, inner)
        key = key_of(export)
        return inner[key] if inner.key?(key)

        context_name(key)
      end

      def new_name
        used = @used.last
        loop do
          name = "v#{@counters.last}"
          @counters[-1] += 1
          return name unless used.include?(name)
        end
      end
    end
  end
end
