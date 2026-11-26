# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Resolves symbolic names, aliases and parameter names while rendering.
    # The base strategy keeps the given names and invents `hint001`-style names
    # for elements that were referenced without ever being named.
    class NameResolver
      def initialize
        @context_names = {}.compare_by_identity # steep:ignore UnannotatedEmptyCollection
      end

      def resolve(symbolic_name, in_entity: false) # rubocop:disable Lint/UnusedMethodArgument
        context_name(symbolic_name)
      end

      def resolve_alias(aliased, define: false, in_last_return: false) # rubocop:disable Lint/UnusedMethodArgument
        context_name(aliased.alias_name)
      end

      def resolve_parameter(parameter) = parameter.name

      def enter_scope(imports); end
      def leave_scope(exports); end

      private

      def context_name(symbolic_name)
        return symbolic_name.value if symbolic_name.resolved?

        @context_names[symbolic_name] ||= "#{symbolic_name.hint}#{format('%03d', @context_names.size + 1)}"
      end
    end
  end
end
