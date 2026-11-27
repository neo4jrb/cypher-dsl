# frozen_string_literal: true

module CypherDSL
  class Renderer
    class Visitor
      # Rendering of node labels: plain names and {Labels} expressions, dynamic
      # (`:$($labels)`) where the dialect allows it, static otherwise.
      module LabelRendering
        STATIC_MESSAGE = 'Cannot render the given Labels in a Cypher pre 5.26 compatible way'

        private

        # One label entry including its leading colon.
        def render_label(label)
          label.is_a?(Labels) ? render_labels_expression(label) : ":#{escape_schema_name(label)}"
        end

        def render_labels_expression(labels)
          return render_static_labels(labels) if !@configuration.dynamic_labels? && static_renderable?(labels)
          return '' if labels.empty?

          ":#{render_labels_tree(labels, nil)}"
        end

        def static_renderable?(labels)
          labels.lhs.nil? && labels.rhs.nil? && %i[leaf colon_conjunction].include?(labels.type)
        end

        # Pre-5.26: the label names are taken from literals and parameter values and rendered as `:A:B`.
        def render_static_labels(labels)
          names = labels.values.flat_map { |value| static_label_names(value.value) }
          names.map { |name| ":#{escape_schema_name(name)}" }.join
        end

        def static_label_names(value)
          case value
          when String then [value]
          when Parameter then value.value? ? static_label_names(value.value) : raise(ArgumentError, STATIC_MESSAGE)
          when ListExpression then value.elements.flat_map { |element| static_label_names(element) }
          when Literal then value.value.is_a?(String) ? [value.value] : raise(ArgumentError, STATIC_MESSAGE)
          when Array then value.flat_map { |item| static_label_names(item) }
          else raise ArgumentError, STATIC_MESSAGE
          end
        end

        # Mirrors the Java renderer's bracketing rules for `&`, `|` and `!`.
        def render_labels_tree(labels, parent)
          current = labels.type
          close = false
          unless labels.leaf?
            close = (!parent.nil? || labels.negated?) && current != parent
            close = false if close && !labels.negated? && (current == :conjunction || parent == :disjunction)
          end

          parts = [] #: Array[String]
          parts << '!' if labels.negated?
          parts << '(' if close
          parts << render_labels_tree(labels.lhs, current) if labels.lhs
          parts << render_label_values(labels, current)
          parts << render_labels_tree(labels.rhs, current) if labels.rhs
          parts << ')' if close
          parts.join
        end

        def render_label_values(labels, current)
          return labels.values.map { |value| render_label_value(value) }.join if labels.leaf?
          if %i[colon_conjunction colon_disjunction].include?(current) && labels.values.any?
            return labels.values.map { |value| render_label_value(value) }.join(':')
          end

          labels.empty? ? '' : Labels::OPERATORS[current]
        end

        def render_label_value(value)
          case value.modifier
          when :static then escape_schema_name(value.value)
          when :all then "$(#{render_expression(value.value)})"
          when :any then "$any(#{render_expression(value.value)})"
          end
        end
      end
    end
  end
end
