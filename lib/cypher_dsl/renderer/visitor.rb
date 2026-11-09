# frozen_string_literal: true

module CypherDSL
  class Renderer
    # Walks a statement and produces Cypher text. One instance per render call:
    # it remembers which named nodes have already been rendered with their
    # content, so later occurrences render as `(name)` only.
    class Visitor
      include Patterns
      include Expressions
      include Conditions
      include LabelRendering

      def initialize(configuration)
        @configuration = configuration
        @visited_names = Set.new
        @defined_aliases = {}
        @names = if configuration.use_generated_names?
                   GeneratedNameResolver.new(configuration.generated_names)
                 else
                   NameResolver.new
                 end
        @renamed_parameters = {}
        @parameter_uses = {}
        @depth = 0
        @in_last_return = false
        @anonymous_parameters = []
        @level = 0
      end

      # The parameters seen while rendering `statement`; see {Renderer#catalog}.
      def catalog(statement = nil) = StatementCatalog.from_uses(@parameter_uses, @renamed_parameters, statement:)

      # A part of a statement on its own.
      def render_fragment(fragment)
        case fragment
        when Search then render_search(fragment).lstrip
        when Node, Relationship, RelationshipChain, NamedPath, QuantifiedPathPattern
          render_pattern_element(fragment)
        when Statement, UnionQuery then render(fragment)
        else Clauses.clause?(fragment) ? render_clause(fragment) : render_expression(fragment)
        end
      end

      def render(statement)
        return render_union(statement) if statement.is_a?(UnionQuery)

        @depth += 1
        last = statement.clauses.size - 1
        leading_use = statement.clauses.first.is_a?(Clauses::Use)
        rendered = statement.clauses.each_with_index.map do |clause, index|
          # A leading USE does not count: `USE g CALL () {…}` opens the statement's scope.
          @first_clause = (index.zero? || (leading_use && index == 1)) && @visited_names.empty?
          @in_last_return = @depth == 1 && index == last && clause.is_a?(Clauses::Return)
          render_clause(clause)
        end.join(break_line)
        statement.prefix ? "#{statement.prefix} #{rendered}" : rendered
      ensure
        @depth -= 1
      end

      private

      # --- pretty printing ------------------------------------------------

      def pretty? = @configuration.pretty_print

      # A clause or entry separator: a newline plus indentation when pretty printing, a space otherwise.
      def break_line(level = @level)
        pretty? ? "\n#{@configuration.indent_unit * level}" : ' '
      end

      # Renders the block one level deeper, e.g. the body of a subquery.
      def nested
        @level += 1
        yield
      ensure
        @level -= 1
      end

      # `opening` + body on its own indented lines + `closing`, or inline when not pretty printing.
      def block(opening, closing, inline_padding: ' ', &body)
        body = nested(&body)
        return "#{opening}#{inline_padding}#{body}#{inline_padding}#{closing}" unless pretty?

        "#{opening}#{break_line(@level + 1)}#{body}#{break_line}#{closing}"
      end

      public

      # Each statement of a union starts from the scope the union was entered with.
      def render_union(union)
        entry_names = @visited_names.dup
        entry_aliases = @defined_aliases.dup
        keyword = union.all ? ' UNION ALL' : ' UNION'
        union.statements.map do |statement|
          @visited_names = entry_names.dup
          @defined_aliases = entry_aliases.dup
          render(statement)
        end.join("#{keyword}#{break_line}")
      end

      # The rendered name of a symbolic name; see {NameResolver}.
      def resolve_name(symbolic_name, in_entity: false) = @names.resolve(symbolic_name, in_entity:)

      private

      # --- clauses ---------------------------------------------------------

      def render_clause(clause)
        case clause
        when Clauses::Match then render_match(clause)
        when Clauses::With then render_with(clause)
        when Clauses::Return then render_projection('RETURN', clause)
        when Clauses::RawReturn then clause.items.map { |item| render_projection_item(item) }.join(', ')
        when Clauses::Create then "CREATE #{render_pattern_elements(clause.pattern_elements)}"
        when Clauses::Merge then render_merge(clause)
        when Clauses::Set then "SET #{render_operations(clause.operations)}"
        when Clauses::Remove then "REMOVE #{render_operations(clause.items)}"
        when Clauses::Delete then render_delete(clause)
        when Clauses::Unwind then render_unwind(clause)
        when Clauses::Finish then 'FINISH'
        when Clauses::Foreach then render_foreach(clause)
        when Clauses::Call then render_call(clause)
        when Clauses::CallSubquery then render_call_subquery(clause)
        when Clauses::LoadCsv then render_load_csv(clause)
        when Clauses::Use then "USE #{clause.graph.is_a?(String) ? clause.graph : render_expression(clause.graph)}"
        when Clauses::Raw then render_raw(clause.expression)
        else raise ArgumentError, "Cannot render clause #{clause.inspect}"
        end
      end

      def render_unwind(clause)
        "UNWIND #{render_expression(clause.expression)} AS #{render_expression(clause.variable)}"
      end

      def render_load_csv(clause)
        parts = []
        if clause.periodic_commit
          rate = clause.periodic_commit == true ? '' : " #{clause.periodic_commit}"
          parts << "USING PERIODIC COMMIT#{rate}"
        end
        parts << (clause.with_headers ? 'LOAD CSV WITH HEADERS' : 'LOAD CSV')
        parts << "FROM #{render_literal(clause.uri)} AS #{render_expression(clause.alias_name)}"
        parts << "FIELDTERMINATOR #{render_literal(clause.field_terminator)}" if clause.field_terminator
        parts.join(' ')
      end

      def render_call(clause)
        name = clause.name_parts.map { |part| Escaper.escape_if_necessary(part) }.join('.')
        arguments = clause.arguments.map { |argument| render_expression(argument) }.join(', ')
        parts = ["CALL #{name}(#{arguments})"]
        yields = clause.yield_items.map { |item| render_projection_item(item) }
        parts << "YIELD #{yields.join(', ')}" unless yields.empty?
        parts << "WHERE #{render_expression(clause.where)}" if clause.where && !clause.where.is_a?(NoCondition)
        parts.join(' ')
      end

      # `CALL (imports) { body }` on Neo4j 5.23+, `CALL { WITH imports body }` before.
      # A subquery is its own scope: only imported names count as visited inside.
      # A leading WITH of plain names in the body is an import list itself.
      def render_call_subquery(clause)
        body, imports = subquery_body_and_imports(clause)
        suffix = clause.in_transactions ? " IN TRANSACTIONS#{" OF #{clause.rows} ROWS" if clause.rows}" : ''
        if @configuration.legacy_subquery_syntax?
          prefix = imports.empty? ? nil : "WITH #{imports.map { |import| render_expression(import) }.join(', ')}"
          opening = 'CALL {'
        else
          list = imports.map { |import| render_expression(import) }.join(', ')
          list = @first_clause ? '' : '*' if imports.empty?
          prefix = nil
          opening = "CALL (#{list}) {"
        end
        rendered = block(opening, '}', inline_padding: '') do
          [prefix, render_in_scope(body, scope_of(imports), imports)].compact.join(break_line)
        end
        "#{rendered}#{suffix}"
      end

      # What a subquery hands back to the outer scope: the items of its final RETURN.
      def exports_of(body)
        return [] unless body.is_a?(Statement) && body.clauses.last.is_a?(Clauses::Return)

        items = body.clauses.last.items
        return :all if items.any?(Asterisk)

        items.select { |item| [SymbolicName, AliasedExpression, Node, Relationship].any? { |type| item.is_a?(type) } }
      end

      # An aliased import (`nodes AS x`) imports the name and renames it with a
      # leading `WITH nodes AS x` inside the body.
      def subquery_body_and_imports(clause)
        body = clause.body
        return [body, clause.imports] if clause.imports.any? && clause.imports.none?(AliasedExpression)
        return renamed_imports(body, clause.imports) if clause.imports.any?
        return [body, []] if body.is_a?(RawExpression) || body.is_a?(UnionQuery)

        first = body.clauses.first
        return [body, []] unless importing_with?(first)

        legacy = @configuration.legacy_subquery_syntax?
        [legacy ? body : Statement.new(body.clauses.drop(1), prefix: body.prefix), legacy ? [] : first.items]
      end

      def renamed_imports(body, imports)
        names = imports.map { |import| import.is_a?(AliasedExpression) ? import.delegate : import }
        rename = Clauses::With.new(distinct: false, items: imports, order: nil, skip: nil, limit: nil, where: nil)
        [Statement.new([rename] + body.clauses, prefix: body.prefix), names]
      end

      def importing_with?(clause)
        clause.is_a?(Clauses::With) && !clause.distinct && clause.order.nil? && clause.skip.nil? &&
          clause.limit.nil? && clause.where.nil? &&
          clause.items.all? { |item| item.is_a?(SymbolicName) || item.is_a?(Asterisk) }
      end

      # Imported names form the subquery's scope; `*` imports the whole current scope.
      def scope_of(imports)
        return @visited_names.dup if imports.any?(Asterisk)

        imports.filter_map { |import| import.is_a?(SymbolicName) ? resolve_name(import) : nil }.to_set
      end

      # A CALL subquery body: only the imports are visible inside, the final RETURN is exported.
      def render_in_scope(body, scope, imports)
        return render_raw(body) if body.is_a?(RawExpression)

        outer_scope = @visited_names
        @visited_names = scope
        @names.enter_scope(imports.any?(Asterisk) ? :all : imports)
        rendered = render(body)
        @names.leave_scope(exports_of(body))
        @visited_names = outer_scope
        rendered
      end

      # A subquery statement rendered within the current scope (EXISTS / COLLECT).
      def render_subquery(statement, imports = [])
        prefix = imports.empty? ? '' : "WITH #{imports.map { |import| render_projection_item(import) }.join(', ')} "
        rendered = render_in_own_scope { render(statement) }
        "#{prefix}#{rendered}"
      end

      # The body of a FOREACH is its own scope: names rendered inside it do not
      # count as visited outside.
      def render_foreach(clause)
        body = render_in_own_scope { clause.clauses.map { |inner| render_clause(inner) }.join(' ') }
        "FOREACH (#{render_expression(clause.variable)} IN #{render_expression(clause.list)} | #{body})"
      end

      def render_match(clause)
        hints = clause.hints.map { |hint| "#{break_line}#{render_hint(hint)}" }
        search = clause.search && render_search(clause.search)
        [('OPTIONAL ' if clause.optional), 'MATCH ', render_pattern_elements(clause.pattern_elements),
         *hints, search, render_where(clause.where)].join
      end

      # `SEARCH name IN (VECTOR INDEX index FOR vector [WHERE …] LIMIT k) [SCORE AS score]`; pretty
      # printed it sits indented under its MATCH with one option per line.
      def render_search(search)
        score = search.score_name && " SCORE AS #{render_expression(search.score_name)}"
        name = render_expression(search.name)
        return " SEARCH #{name} IN (#{search_options(search).join(' ')})#{score}" unless pretty?

        body = nested { nested { search_options(search).join(break_line) } }
        "#{break_line(@level + 1)}SEARCH #{name} IN (#{break_line(@level + 2)}#{body}#{break_line(@level + 1)})#{score}"
      end

      def search_options(search)
        predicate = search.predicates.inject { |all, predicate| all.and(predicate) }
        options = ["VECTOR INDEX #{Escaper.escape_if_necessary(search.index_name)}",
                   "FOR #{render_expression(search.vector)}"]
        options << "WHERE #{render_expression(predicate)}" if predicate
        options << "LIMIT #{search.top_k}" if search.top_k
        options
      end

      def render_hint(hint)
        case hint.type
        when :join then "USING JOIN ON #{hint.names.map { |name| render_expression(name) }.join(', ')}"
        when :scan then "USING SCAN #{render_expression(hint.container)}:#{escape_schema_name(hint.schema_name)}"
        else
          keyword = hint.type == :index_seek ? 'USING INDEX SEEK' : 'USING INDEX'
          properties = hint.property_names.map { |name| Escaper.escape_if_necessary(name) }.join(', ')
          "#{keyword} #{render_expression(hint.container)}:#{escape_schema_name(hint.schema_name)}(#{properties})"
        end
      end

      def render_merge(clause)
        actions = clause.actions.map do |action|
          separator = pretty? ? break_line(@level + 1) : ' '
          "#{separator}ON #{action.type == :on_match ? 'MATCH' : 'CREATE'} SET #{render_operations(action.operations)}"
        end
        "MERGE #{render_pattern_elements(clause.pattern_elements)}#{actions.join}"
      end

      def render_operations(operations)
        operations.map { |operation| render_expression(operation) }.join(', ')
      end

      def render_delete(clause)
        expressions = clause.expressions.map { |expression| render_expression(expression) }
        "#{'DETACH ' if clause.detach}DELETE #{expressions.join(', ')}"
      end

      # WITH ends a query part: only the names it projects stay in scope, so a
      # node that is not carried over renders with its labels again afterwards.
      # The projected names are already known to the clause's own WHERE, next to
      # the names of the part it ends: `WITH n AS m WHERE (m)-->()`. A `*` keeps
      # the whole current scope.
      def render_with(clause)
        projection = render_projection('WITH', clause)
        exported = exported_names(clause.items)
        exported.merge(@visited_names) if clause.items.include?(Asterisk::INSTANCE)
        @visited_names.merge(exported)
        rendered = "#{projection}#{render_where(clause.where)}"
        @visited_names = exported
        rendered
      end

      def exported_names(items)
        items.filter_map do |item|
          case item
          when AliasedExpression then @names.resolve_alias(item, in_last_return: @in_last_return)
          when SymbolicName then resolve_name(item)
          when Node, Relationship then item.symbolic_name && resolve_name(item.symbolic_name)
          end
        end.to_set
      end

      def render_projection(keyword, clause)
        items = clause.items.map { |item| render_projection_item(item) }.join(', ')
        parts = ["#{keyword} #{'DISTINCT ' if clause.distinct}#{items}"]
        parts << "ORDER BY #{clause.order.items.map { |item| render_sort_item(item) }.join(', ')}" if clause.order
        parts << "SKIP #{render_expression(clause.skip)}" if clause.skip
        parts << "LIMIT #{render_expression(clause.limit)}" if clause.limit
        parts.join(' ')
      end

      # In RETURN/WITH an aliased expression is defined once (`expr AS alias`);
      # afterwards, and anywhere else, it is a reference and renders as the alias.
      def render_projection_item(item)
        return render_expression(item) unless item.is_a?(AliasedExpression)

        alias_name = @names.resolve_alias(item, in_last_return: @in_last_return)
        return Escaper.escape_if_necessary(alias_name) if alias_defined?(item, alias_name)

        delegate = render_expression(item.delegate)
        alias_name = @names.resolve_alias(item, define: true, in_last_return: @in_last_return)
        @defined_aliases[alias_name] = item.delegate
        "#{delegate} AS #{Escaper.escape_if_necessary(alias_name)}"
      end

      def render_aliased_reference(item)
        alias_name = @names.resolve_alias(item, in_last_return: @in_last_return)
        return Escaper.escape_if_necessary(alias_name) if alias_defined?(item, alias_name)

        render_expression(item.delegate)
      end

      # The same alias may be given to another expression later (`WITH a AS x RETURN count(*) AS x`).
      def alias_defined?(item, alias_name)
        @defined_aliases.key?(alias_name) && @defined_aliases[alias_name] == item.delegate
      end

      def render_pattern_elements(elements)
        elements.map { |element| render_pattern_element(element) }.join(', ')
      end

      # WHERE goes on its own line when pretty printing.
      def render_where(condition)
        return nil if condition.nil? || condition.is_a?(NoCondition)

        "#{break_line}WHERE #{render_expression(condition)}"
      end

      def render_sort_item(item)
        [render_expression(item.expression), item.direction&.to_s&.upcase].compact.join(' ')
      end
    end
  end
end
