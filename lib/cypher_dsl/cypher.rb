# frozen_string_literal: true

module CypherDSL
  # The main entry point of the DSL. Mirrors the static factory methods of the
  # Java `org.neo4j.cypherdsl.core.Cypher` class in snake_case.
  module Cypher
    extend Functions

    module_function

    # --- pattern elements ------------------------------------------------

    # A node with one primary label and optional additional labels (or lists of
    # them); a map among the arguments (`Cypher.node('Test', Cypher.map_of(…))`)
    # sets its properties.
    def node(primary_label, *additional_labels)
      additional_labels = additional_labels.flatten
      properties = additional_labels.find { |label| [MapExpression, Hash].any? { |type| label.is_a?(type) } }
      labels = [primary_label, *additional_labels.reject { |label| properties && label.equal?(properties) }]
      labels = labels.map { |label| label.is_a?(Labels) ? label : label.to_s }
      raise ArgumentError, 'A primary label is required.' if blank_label?(labels.first)
      raise ArgumentError, 'An empty label is not allowed.' if labels.drop(1).any? { |label| blank_label?(label) }

      node = Node.new(labels:)
      properties ? node.with_properties(properties) : node
    end

    def blank_label?(label) = label.is_a?(String) && label.strip.empty?
    private_class_method :blank_label?

    # A node without labels, optionally named.
    # `Cypher.search(:movie).in('index').for_vector(v).limit(4).build`, see {Search}.
    def search(name) = Search::Builder.new(name && SymbolicName.of(name))

    # `vector([1, 2, 3], 3, INTEGER NOT NULL)`, see {VectorLiteral}.
    def vector(elements, type = nil) = VectorLiteral.of(elements, type)

    # Label expressions: `Cypher.node(Cypher.exactly_label('A').or('B'))`, `Cypher.node(Cypher.all_labels($labels))`.
    def exactly_label(label) = Labels.exactly(label)
    def all_labels(expression) = Labels.all(expression)
    def any_label(expression) = Labels.any(expression)

    def any_node(name = nil)
      node = Node.new(labels: [])
      name ? node.named(name) : node
    end

    # --- names, properties, parameters -----------------------------------

    def name(value) = SymbolicName.of(value)

    # `Cypher.property(:n, :name)` → `n.name`; the container may also be an expression,
    # and a name may be an expression for a dynamic lookup (`n[$prop]`).
    def property(container, *names)
      container = SymbolicName.of(container) unless container.is_a?(Expression)
      Property.new(container, names.flatten)
    end

    # `$name`, optionally with its value; see {Parameter}.
    def parameter(name, value = Parameter::NO_VALUE) = Parameter.new(name, value)

    # A parameter named by the renderer (`$pcdsl01`, …), carrying its value.
    def anon_parameter(value) = Parameter.anonymous(value)

    # --- literals --------------------------------------------------------

    # Wraps a Ruby value as a literal; expressions pass through unchanged.
    def literal_of(value) = Literal.of(value)

    def literal_true = Literal::TRUE
    def literal_false = Literal::FALSE
    def literal_null = Literal::NULL

    def map_of(*keys_and_values) = MapExpression.of(*keys_and_values)
    def list_of(*expressions) = ListExpression.of(*expressions)

    def asterisk = Asterisk::INSTANCE

    # --- conditions ------------------------------------------------------

    def is_true = ConstantCondition::TRUE
    def is_false = ConstantCondition::FALSE
    def no_condition = NoCondition::INSTANCE
    def not(condition_or_pattern) = Condition.coerce(condition_or_pattern).not
    def includes_all(list_expression, list) = Expression.coerce(list_expression).includes_all(list)
    def includes_any(list_expression, list) = Expression.coerce(list_expression).includes_any(list)

    # `[pattern WHERE … | …]`; continue with `where` and `returning`.
    def list_based_on(pattern) = PatternComprehension.new(pattern)

    # `[variable IN list WHERE … | …]`; continue with `in`, `where` and `returning`.
    def list_with(variable) = ListComprehension.new(variable)

    # `Cypher.path(:p).defined_by(pattern)` for `MATCH p = pattern`; `.get` for the bare name.
    def path(name) = NamedPath::Ongoing.new(SymbolicName.of(name))

    # Path selectors, `Cypher.any_shortest.named(:p).defined_by(pattern)` → `p = ANY pattern`.
    def any_shortest = NamedPath::Selector.new('ANY')
    def all_shortest = NamedPath::Selector.new('ALL SHORTEST', legacy_function: 'allShortestPaths')
    def shortest_k(count) = NamedPath::Selector.shortest_k(count)
    def shortest_k_groups(count) = NamedPath::Selector.shortest_k(count, groups: true)

    # `EXISTS { pattern }` / `EXISTS { pattern, pattern }` / `EXISTS { [WITH imports] statement }`.
    # A property gives the condition `n.prop IS NOT NULL` (`exists(n.prop)` on Neo4j 4), any other
    # plain expression the `exists(expr)` function.
    def exists(body, *imports)
      # @type var body: untyped
      raise ArgumentError, 'The expression or pattern for exists() is required.' if body.nil?
      return PropertyExistsCondition.new(body) if body.is_a?(Property)
      return function('exists', body) if body.is_a?(Expression) && !body.is_a?(Statement) && !pattern?(body)

      ExistsCondition.new(body, imports.flatten.map { |import| Expression.coerce(import) })
    end

    PATTERN_TYPES = [Relationship, RelationshipChain, QuantifiedPathPattern, NamedPath].freeze
    private_constant :PATTERN_TYPES

    def pattern?(value) = PATTERN_TYPES.any? { |type| value.is_a?(type) }

    # The condition `name:Label`, for a name that may stand for a node or a relationship.
    def has_labels_or_type(name, *labels) = HasLabelCondition.new(SymbolicName.of(name), labels.flatten)

    # List predicates: `Cypher.all(:x).in(list).where(condition)`.
    def all(variable) = ListPredicate::Ongoing.new('all', variable)
    def any(variable) = ListPredicate::Ongoing.new('any', variable)
    def none(variable) = ListPredicate::Ongoing.new('none', variable)
    def single(variable) = ListPredicate::Ongoing.new('single', variable)

    def sub_list_until(list, end_index) = ListOperator.sublist(Expression.coerce(list), nil, end_index)
    def sub_list_from(list, start_index) = ListOperator.sublist(Expression.coerce(list), start_index, nil)
    def sub_list(list, start_index = nil, end_index = nil) = sublist(list, start_index, end_index)

    def range(start_value, end_value, step = nil) = function('range', *[start_value, end_value, step].compact)

    # --- operations ------------------------------------------------------

    def set(target, value) = Operation.new(target, '=', Expression.coerce(value))
    def set_label(node, *labels) = LabelOperation.new(node, labels)
    def remove_label(node, *labels) = LabelOperation.new(node, labels, remove: true)
    def mutate(target, expression) = Operation.new(target, '+=', Expression.coerce(expression))
    def minus(expression) = UnaryOperation.new('-', Expression.coerce(expression))
    def plus(expression) = UnaryOperation.new('+', Expression.coerce(expression))
    def value_at(list, index) = ListOperator.value_at(Expression.coerce(list), index)

    def sublist(list, start_index = nil, end_index = nil)
      ListOperator.sublist(Expression.coerce(list), start_index, end_index)
    end

    # `CASE … END`; `case_expression(subject)` for the simple form, no argument for the generic one.
    def case_expression(subject = nil) = CaseExpression.new(subject: subject && Expression.coerce(subject))

    # --- sorting and functions --------------------------------------------
    # Plain functions live in {Functions}; these overloads also accept patterns and statements.

    # `collect(expression)`, or `COLLECT { statement }` when given a statement.
    def collect(expression_or_statement)
      return CollectExpression.new(expression_or_statement) if expression_or_statement.is_a?(Statement)

      function('collect', expression_or_statement)
    end

    # A map projection on a name: `Cypher.create_projection(:n, 'title')` → `n{.title}`.
    def create_projection(name, *entries) = MapProjection.new(SymbolicName.of(name), entries.flatten)

    # A sort item, optionally with its direction (`:asc` / `:desc`).
    def sort(expression, direction = nil) = SortItem.new(Expression.coerce(expression), direction)

    # A string as a Cypher string literal, `'…'` with quotes and backslashes escaped.
    def quote(string) = Literal.quote(string)

    # A short textual form of an expression: the name of a named element, alias or
    # symbolic name, `container.name` for a property, the rendered Cypher otherwise.
    def format(expression)
      case expression
      when Node, Relationship then expression.required_symbolic_name.value
      when AliasedExpression then expression.alias_name.value
      when SymbolicName then expression.value
      when Property then ([expression.container] + expression.names).map { |part| format_name(part) }.join('.')
      else Renderer.plain.render_fragment(expression)
      end
    end

    def format_name(name) = name.is_a?(Expression) ? format(name) : name
    private_class_method :format_name

    # `size(list)` or `size(pattern)`.
    def size(expression_or_pattern)
      # @type var expression_or_pattern: untyped
      argument = pattern?(expression_or_pattern) ? PatternExpression.new(expression_or_pattern) : expression_or_pattern
      function('size', argument)
    end

    # `count(expression)`, or `COUNT { [WITH imports] pattern }` / `COUNT { … statement }`
    # for patterns and statements.
    def count(expression_or_pattern, *imports)
      # @type var expression_or_pattern: untyped
      subquery = pattern?(expression_or_pattern) || expression_or_pattern.is_a?(Statement) ||
                 expression_or_pattern.is_a?(UnionQuery)
      return FunctionInvocation.new('count', [Expression.coerce(expression_or_pattern)]) unless subquery

      CountExpression.new(expression_or_pattern, imports.flatten.map { |import| Expression.coerce(import) })
    end

    # `Cypher.call('db.labels')` / `Cypher.call('db', 'labels')`: a procedure call (see {StandaloneCall});
    # `Cypher.call(statement, imports…)`: a `CALL { subquery }`.
    def call(*arguments)
      # @type var arguments: untyped
      return StatementBuilder.new.call(*arguments) if arguments.first.is_a?(Statement)

      StandaloneCall.new(arguments)
    end

    # `Cypher.use('graph', statement)`: the statement prefixed with `USE graph`. An
    # expression as the target (a name, literal or parameter) is wrapped in
    # `graph.byName(…)` unless it already is a function call.
    def use(graph, statement)
      raise ArgumentError, 'Nested USE clauses are not supported' if statement.clauses.first.is_a?(Clauses::Use)
      if statement.prefix
        raise ArgumentError, "#{DECORATED[statement.prefix]} statements are not supported inside USE clauses"
      end

      graph = graph_by_name(graph) if graph.is_a?(Expression) && !graph.is_a?(FunctionInvocation)
      graph = graph.to_s unless graph.is_a?(Expression)
      Statement.new([Clauses::Use.new(graph:)] + statement.clauses)
    end

    DECORATED = { 'EXPLAIN' => "EXPLAIN'ed", 'PROFILE' => "PROFILE'd" }.freeze
    private_constant :DECORATED

    # `Cypher.load_csv('file:///x.csv').as(:line)`.
    def load_csv(uri, positional_headers = false, with_headers: positional_headers) # rubocop:disable Style/OptionalBooleanParameter
      StatementBuilder.new.load_csv(uri, with_headers:)
    end

    # `Cypher.using_periodic_commit(500).load_csv(uri).as(:line)`.
    def using_periodic_commit(rate = nil) = UsingPeriodicCommit.new(rate:)

    # Imports for an EXISTS / COLLECT subquery: `Cypher.subquery_with(x).collect(statement)`.
    def subquery_with(*imports) = SubqueryWith.new(imports)

    # `CALL () { raw cypher }`; continues as a statement builder.
    def call_raw_cypher(cypher)
      clause = Clauses::CallSubquery.new(body: RawExpression.new(cypher), imports: [],
                                         in_transactions: false, rows: nil)
      StatementBuilder.new.send(:append, clause, nil)
    end

    # Verbatim Cypher, the escape hatch; `$E` placeholders take the arguments in
    # order, `\$E` is a literal `$E`. See {RawExpression.create}.
    def raw(*) = RawExpression.create(*)

    # Static comparison forms, `Cypher.gt(a, b)` etc.
    def eq(left, right) = Expression.coerce(left).is_equal_to(right)
    def ne(left, right) = Expression.coerce(left).is_not_equal_to(right)
    def gt(left, right) = Expression.coerce(left).gt(right)
    def gte(left, right) = Expression.coerce(left).gte(right)
    def lt(left, right) = Expression.coerce(left).lt(right)
    def lte(left, right) = Expression.coerce(left).lte(right)

    # --- statement builders -----------------------------------------------

    def match(*pattern_elements) = StatementBuilder.new.match(*pattern_elements)
    def optional_match(*pattern_elements) = StatementBuilder.new.optional_match(*pattern_elements)
    def create(*pattern_elements) = StatementBuilder.new.create(*pattern_elements)
    def merge(*pattern_elements) = StatementBuilder.new.merge(*pattern_elements)
    def with(*expressions) = StatementBuilder.new.with(*expressions)
    def unwind(*expressions) = StatementBuilder.new.unwind(*expressions)
    def returning(*expressions) = StatementBuilder.new.returning(*expressions)
    def returning_distinct(*expressions) = StatementBuilder.new.returning_distinct(*expressions)
    def returning_raw(*expressions) = StatementBuilder.new.returning_raw(*expressions)

    def union(*statements) = UnionQuery.create(statements, all: false)
    def union_all(*statements) = UnionQuery.create(statements, all: true)
  end
end
