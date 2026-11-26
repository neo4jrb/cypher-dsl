# frozen_string_literal: true

module CypherDSL
  class Renderer
    class Visitor
      # Rendering of expressions, conditions, operations, functions and subquery expressions.
      module Expressions
        private

        def render_expression(expression)
          case expression
          when SymbolicName then Escaper.escape_if_necessary(resolve_name(expression))
          when Node, Relationship then render_expression(expression.required_symbolic_name)
          when Property then render_property(expression)
          when Literal then render_literal(expression.value)
          when Parameter then render_parameter(expression)
          when Asterisk then '*'
          when AliasedExpression then render_aliased_reference(expression)
          when NamedPath then render_expression(expression.symbolic_name)
          when RawExpression then render_raw(expression)
          when CollectExpression
            block('COLLECT {', '}') { render_subquery(expression.statement, expression.imports) }
          when CountExpression then render_count(expression)
          when FunctionInvocation then render_function_invocation(expression)
          when SortItem then render_sort_item(expression)
          when CaseExpression then render_case(expression)
          when UnaryOperation then "#{expression.operator}#{render_expression(expression.expression)}"
          when ListOperator then render_list_operator(expression)
          else render_container_expression(expression)
          end
        end

        def render_case(case_expression)
          parts = ['CASE']
          parts << render_expression(case_expression.subject) if case_expression.subject
          case_expression.whens.each do |condition, value|
            parts << "WHEN #{render_expression(condition)} THEN #{render_expression(value)}"
          end
          parts << "ELSE #{render_expression(case_expression.default)}" if case_expression.default
          parts << 'END'
          parts.join(' ')
        end

        def render_list_operator(operator)
          list = render_expression(operator.list)
          return "#{list}[#{render_expression(operator.start_index)}]" unless operator.slice

          from = operator.start_index && render_expression(operator.start_index)
          to = operator.end_index && render_expression(operator.end_index)
          "#{list}[#{from}..#{to}]"
        end

        def render_container_expression(expression)
          case expression
          when MapExpression then render_map(expression)
          when ListExpression then "[#{expression.elements.map { |element| render_expression(element) }.join(', ')}]"
          when PatternComprehension then render_pattern_comprehension(expression)
          when ListComprehension then render_list_comprehension(expression)
          when MapProjection then render_map_projection(expression)
          when LabelOperation then render_labels(expression.node, expression.labels)
          when Reduction then render_reduction(expression)
          when PatternExpression then render_pattern_expression(expression.pattern)
          when VectorLiteral then expression.as_string
          else render_condition_or_operation(expression)
          end
        end

        def render_reduction(reduction)
          accumulator = "#{render_expression(reduction.accumulator)} = #{render_expression(reduction.initial_value)}"
          "reduce(#{accumulator}, #{render_expression(reduction.variable)} IN #{render_expression(reduction.list)} " \
            "| #{render_expression(reduction.mapper)})"
        end

        def render_labels(node, labels)
          "#{render_expression(node)}#{labels.map { |label| render_label(label) }.join}"
        end

        def render_condition_or_operation(expression)
          case expression
          when Comparison then render_comparison(expression)
          when CompoundCondition then render_compound_condition(expression)
          when ConstantCondition then expression.value.to_s
          when ExpressionCondition then render_expression(expression.expression)
          when ExistsCondition then render_exists(expression)
          when PropertyExistsCondition then render_property_exists(expression)
          when RelationshipPatternCondition then render_pattern_expression(expression.pattern)
          when ListPredicate then render_list_predicate(expression)
          when HasLabelCondition then render_labels(expression.node, expression.labels)
          when Operation then render_operation(expression)
          else raise ArgumentError, "Cannot render expression #{expression.inspect}"
          end
        end

        def render_operation(operation)
          left = render_expression(operation.left)
          right = render_expression(operation.right)
          return "#{left}^#{right}" if operation.operator == '^'

          rendered = "#{left} #{operation.operator} #{right}"
          operation.assignment? ? rendered : "(#{rendered})"
        end

        # A plain relationship pattern uses the `exists()` function; quantified
        # patterns and statements need the `EXISTS { }` subquery form.
        def render_exists(condition)
          body = condition.body
          return block('EXISTS {', '}') { render_subquery(body, condition.imports) } if body.is_a?(Statement)
          return "EXISTS { #{render_in_own_scope { render_pattern_elements(body) }} }" if body.is_a?(Array)
          return "EXISTS { #{render_pattern_element(body)} }" if quantified?(body)

          "exists(#{render_pattern_expression(body)})"
        end

        # A pattern body renders bare; with imports it needs a MATCH after the WITH.
        def render_count(count)
          body = count.body
          return block('COUNT {', '}') { render_subquery(body, count.imports) } unless pattern_body?(body)

          rendered = render_in_own_scope do
            imports = count.imports.map { |import| render_projection_item(import) }
            parts = [("WITH #{imports.join(', ')} MATCH" unless imports.empty?), render_pattern_element(body)]
            parts << "WHERE #{render_expression(count.where_condition)}" if count.where_condition
            parts.compact.join(' ')
          end
          "COUNT { #{rendered} }"
        end

        def pattern_body?(body) = !(body.is_a?(Statement) || body.is_a?(UnionQuery))

        # Renders with the current scope, discarding names introduced inside.
        def render_in_own_scope
          # @type var outer_scope: Set[String]
          outer_scope = @visited_names.dup
          @names.enter_scope(:all)
          yield
        ensure
          @names.leave_scope([])
          @visited_names = outer_scope
        end

        def quantified?(pattern)
          case pattern
          when QuantifiedPathPattern then true
          when Relationship then !pattern.details.quantifier.nil?
          when RelationshipChain then pattern.relationships.any? { |relationship| quantified?(relationship) }
          else false
          end
        end

        # The predicate's variable is in scope inside its WHERE.
        def render_list_predicate(predicate)
          variable = render_expression(predicate.variable)
          condition = with_names_in_scope([variable]) { render_expression(predicate.condition) }
          "#{predicate.predicate}(#{variable} IN #{render_expression(predicate.list)} WHERE #{condition})"
        end

        def with_names_in_scope(names)
          # @type var added: Array[String]
          added = names.reject { |name| @visited_names.include?(name) }
          @visited_names.merge(added)
          yield
        ensure
          @visited_names.subtract(added)
        end

        def render_map_projection(projection)
          subject = render_expression(projection.subject)
          render_entries("#{subject}#{' ' if pretty?}{", '}') do
            projection.entries.map do |kind, *args|
              case kind
              when :all then '.*'
              when :lookup then ".#{Escaper.escape_if_necessary(args.first)}"
              when :property then ".#{Escaper.escape_if_necessary(args.first.names.first)}"
              when :pair then "#{Escaper.escape_if_necessary(args.first)}: #{render_expression(args.last)}"
              else render_expression(args.first)
              end
            end
          end
        end

        # A pattern comprehension is its own scope: names it introduces do not
        # count as visited outside of it.
        def render_pattern_comprehension(comprehension)
          render_in_own_scope do
            parts = [render_pattern_element(comprehension.pattern)]
            parts << "WHERE #{render_expression(comprehension.where_condition)}" if comprehension.where_condition
            projection = comprehension.projection.map { |expression| render_expression(expression) }
            parts << "| #{projection.size == 1 ? projection.first : "[#{projection.join(', ')}]"}"
            "[#{parts.join(' ')}]"
          end
        end

        def render_list_comprehension(comprehension)
          parts = ["#{render_expression(comprehension.variable)} IN #{render_expression(comprehension.list)}"]
          parts << "WHERE #{render_expression(comprehension.where_condition)}" if comprehension.where_condition
          parts << "| #{render_expression(comprehension.projection)}" if comprehension.projection
          "[#{parts.join(' ')}]"
        end

        # Records every use for the catalog; anonymous parameters get `pcdslNN`,
        # shared between anonymous parameters with equal values.
        def render_parameter(parameter)
          name = parameter.anonymous? ? anonymous_parameter_name(parameter) : @names.resolve_parameter(parameter)
          @renamed_parameters[parameter.name] = name if !parameter.anonymous? && name != parameter.name
          (@parameter_uses[name] ||= []) << parameter.value
          "$#{Escaper.escape_parameter_name(name)}"
        end

        def anonymous_parameter_name(parameter)
          index = @anonymous_parameters.index(parameter)
          unless index
            @anonymous_parameters << parameter
            index = @anonymous_parameters.size - 1
          end
          format('pcdsl%02d', index + 1)
        end

        def render_property(property)
          lookups = property.names.map do |name|
            name.is_a?(Expression) ? "[#{render_expression(name)}]" : ".#{Escaper.escape_if_necessary(name)}"
          end
          "#{render_expression(property.container)}#{lookups.join}"
        end

        # Verbatim text with its embedded expressions rendered (and their parameters collected).
        def render_raw(raw)
          raw.parts.map { |part| part.is_a?(String) ? part : render_expression(part) }.join
        end

        def render_literal(value)
          case value
          when String then Literal.quote(value)
          when nil then 'NULL'
          when true, false, Numeric then value.to_s
          when DateTime, Time then "datetime('#{value.iso8601}')"
          when Date then "date('#{value.iso8601}')"
          else raise ArgumentError, "Cannot render literal #{value.inspect}"
          end
        end

        def render_map(map)
          render_entries('{', '}') do
            map.entries.map { |key, value| "#{Escaper.escape_if_necessary(key)}: #{render_expression(value)}" }
          end
        end

        # Comma separated entries, one per indented line when pretty printing.
        def render_entries(opening, closing, &entries)
          entries = nested(&entries)
          return "#{opening}#{entries.join(', ')}#{closing}" unless pretty?

          "#{opening}#{break_line(@level + 1)}#{entries.join(",#{break_line(@level + 1)}")}#{break_line}#{closing}"
        end

        def render_function_invocation(invocation)
          arguments = invocation.arguments.map do |argument|
            rendered = render_expression(argument)
            # Pretty printed, a map argument keeps a space after the parenthesis: `collect( {`.
            pretty? && rendered.start_with?('{') ? " #{rendered}" : rendered
          end
          name = invocation.function_name
          legacy = @configuration.legacy_functions?
          # Neo4j 4 has no elementId(); the closest equivalent is the stringified internal id.
          return "toString(id(#{arguments.join(', ')}))" if name == 'elementId' && legacy

          name = 'point.distance' if name == 'distance' && !legacy
          "#{name}(#{'DISTINCT ' if invocation.distinct}#{arguments.join(', ')})"
        end

        def escape_schema_name(name)
          @configuration.always_escape_names ? Escaper.escape(name) : Escaper.escape_if_necessary(name)
        end
      end
    end
  end
end
