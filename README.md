# cypher-dsl

A Ruby DSL (builder) for the [Cypher](https://neo4j.com/docs/cypher-manual/current/)
query language, modelled on the design of Neo4j's
[Cypher-DSL for Java](https://github.com/neo4j/cypher-dsl).

**Status: early development.** The API is being built test-first against
specifications translated from the Java project's test suite, so rendered
output is meant to match Cypher-DSL byte for byte.

## Design

- **Immutable AST.** Every builder call returns a new object; a built
  `Statement` is a frozen tree that can be rendered, inspected or transformed.
- **Part-aware builder.** Cypher is a linear sequence of parts chained by
  `WITH`, and clauses keep the order you wrote them. The builder's states
  mirror which clause may follow which, exactly as the Java `StatementBuilder`
  does.
- **Rendering is separate from the tree.** A `Renderer` turns a `Statement` into
  Cypher text and collects parameters; options such as identifier escaping and
  pretty printing live in a `Configuration`.
- **Names follow the Java API in snake_case**, so examples and tests from the
  Java project translate mechanically:

  ```ruby
  include CypherDSL

  statement = Cypher.match(Cypher.node('S1').named(:n))
    .where(Cypher.property(:n, :a).is_equal_to(Cypher.literal_of('A')))
    .with(:n)
    .match(Cypher.any_node(:n).relationship_to(Cypher.node('S2').named(:m), 'SOMEHOW_RELATED'))
    .returning(:n, :m)
    .build

  statement.cypher
  # => "MATCH (n:`S1`) WHERE n.a = 'A' WITH n MATCH (n)-[:`SOMEHOW_RELATED`]->(m:`S2`) RETURN n, m"
  ```

- **No ActiveSupport.** The only runtime dependency is Zeitwerk.

## Parameters

Parameters render as `$name`; give them a value and the statement hands back
the map a driver needs:

```ruby
statement = Cypher.match(Cypher.node('User').named(:u))
  .where(Cypher.property(:u, :name).is_equal_to(Cypher.parameter(:name, 'Neo')))
  .returning(:u)
  .build

statement.cypher          # => "MATCH (u:`User`) WHERE u.name = $name RETURN u"
statement.parameters      # => {"name" => "Neo"}
statement.parameter_names # => ["name"]
```

`Cypher.anon_parameter(value)` lets the renderer pick the name (`$pcdsl01`, …).
Binding one name to two different values raises `ConflictingParametersException`.

`statement.catalog` also lists the expressions a statement hands back, i.e. the
names and expressions of its final `RETURN` or `YIELD`:

```ruby
statement.catalog.identifiable_expressions # => [Cypher.name(:u)]
```

## Raw Cypher

`Cypher.raw` embeds Cypher text verbatim. `$E` placeholders take the arguments in
order, expressions as they are and anything else as a literal, while a `$name` that
matches a named parameter among the arguments binds that parameter; `\$E` is a literal `$E`:

```ruby
Cypher.returning(Cypher.raw('($E + $E) * $factor', Cypher.parameter(:a), 2, Cypher.parameter(:factor, 3)).as(:r))
  .build.cypher # => "RETURN ($a + 2) * $factor AS r"
```

A raw fragment is also accepted as a pattern element, as a condition, as a `SET`
operation, and `raw_clause` renders a whole clause verbatim. These are escape hatches
for DSLs that have to pass user-written Cypher through; a raw condition combined with
others is parenthesised so its precedence survives:

```ruby
Cypher.match(Cypher.raw('(n)-[:KNOWS]->(m)'))
  .where(Cypher.property(:n, :age).gt(30).and(Cypher.raw('m.name STARTS WITH "A" OR m.vip')))
  .raw_clause('CALL db.labels() YIELD label')
  .returning(:n, :label).build.cypher
# => "MATCH (n)-[:KNOWS]->(m) WHERE (n.age > 30 AND (m.name STARTS WITH \"A\" OR m.vip)) CALL db.labels() YIELD label RETURN n, label"
```

Every expression and pattern answers `to_s` with its plain Cypher, e.g.
`Cypher.node('Person').named(:n).to_s # => "(n:Person)"`.

## Rendering options

```ruby
config = Renderer::Configuration.new_config
  .with_dialect(Renderer::Dialect::NEO4J_4)   # default: NEO4J_5_DEFAULT_CYPHER
  .always_escape_names(false)                  # default: true, false when pretty printing
  .with_pretty_print(true)                     # one clause per line, indented blocks
  .with_indent_style(:tab)                     # or .with_indent_size(4)
  .disable_dynamic_labels                      # render n:$($labels) statically
  .build
Renderer.get_renderer(config).render(statement)
Renderer.get_renderer(Renderer::Configuration.pretty_printing).render(statement)
```

The dialects mirror the Java enum: `NEO4J_4`, `NEO4J_5`, `NEO4J_5_23`, `NEO4J_5_26`,
`NEO4J_5_DEFAULT_CYPHER`, `NEO4J_5_CYPHER_5`, `NEO4J_5_CYPHER_25` and `NEO4J_2025`.
The dialect decides how `CALL { }` subqueries import variables (`CALL (u) { … }` from
Neo4j 5.23 on, `CALL { WITH u … }` before), whether paths use `shortestPath()` or
`SHORTEST 1`, `exists(n.prop)` or `n.prop IS NOT NULL`, `distance()` or
`point.distance()`, whether `elementId()` exists, whether label expressions may be
dynamic (`n:$($labels)`, Neo4j 5.26+) and whether the statement carries a `CYPHER 5`
or `CYPHER 25` prefix.

### Generated names

`with_generated_names(true)` rewrites every variable, alias and parameter name while
rendering (`v0`, `v1`, … and `p0`, `p1`, …), scope by scope, so that statements that
differ only in their names render identically, which is useful as a query-cache key.
A subset of the Java `GeneratedNames` flags narrows what gets rewritten:

```ruby
config = Renderer::Configuration.new_config
  .with_generated_names(%i[entity_names parameter_names])   # or true for all flags
  .build
renderer = Renderer.get_renderer(config)
renderer.render(statement)                     # => "MATCH (v0:`Movie`) WHERE v0.title = $p0 RETURN v0"
renderer.catalog(statement).renamed_parameters # => {"title" => "p0"}
```

The flags are `entity_names`, `parameter_names`, `all_aliases`, `internal_aliases_only`
(all aliases except those of the final `RETURN`) and `reuse_aliases`.

## Installation

Pre-releases are not picked up by a bare requirement, so name the version:

```ruby
gem 'cypher-dsl', '0.1.0'
```

Requires Ruby 3.4 or newer.

## Licence

The Ruby source is MIT licensed (see `LICENSE.txt`). The specifications are
translated from Cypher-DSL's Apache-2.0 test suite; see `NOTICE`.
