# frozen_string_literal: true

# Public API usage that must type check against sig/. Nothing loads this file:
# `steep check` runs it (Steepfile target `usage`) to catch signatures that are
# narrower than what the DSL accepts at runtime. Add a line here when a review
# or a consumer finds a supported call that Steep rejects.

module CypherDSL
  n = Cypher.node('N').named(:n)
  dog = Cypher.node('Dog').named(:dog)
  p = Cypher.name(:p)
  x = Cypher.name(:x)
  inner = Cypher.match(Cypher.any_node(:n)).returning(:n).build

  # literals keep their concrete type
  Cypher.literal_of('text').as_string
  Literal.of('text').as_string
  Cypher.literal_of({ a: 1 }).to_s
  Cypher.literal_of([1, 2]).to_s
  Cypher.literal_of(Cypher.name(:n)).to_s

  # exists / count: property, pattern, statement or plain expression
  Cypher.exists(n.property(:foo)).not
  Cypher.exists(n.relationship_to(dog, 'HAS_DOG')).and(Cypher.exists(x))
  Cypher.exists(inner, Cypher.name(:n)).not
  Cypher.count(n.relationship_to(dog, 'HAS_DOG')).where(n.property(:name).eq(dog.property(:name))).gt(1)
  Cypher.count(inner).gt(1)
  Cypher.count(n.property(:name)).gt(1)

  # procedure calls and subqueries
  Cypher.call('db.labels').yield(:label)
  Cypher.call('db', 'labels').yield(:label)
  Cypher.call(inner).returning(:n)
  Cypher.call(inner, :p, Cypher.name(:q)).returning(:n)
  Statement.builder.call('db.labels').yield(:label)
  Statement.builder.call(inner).returning(:n)
  Cypher.with(:p).call_in_transactions(inner, :p)
  Cypher.with(:p).call_in_transactions(inner, 2, :p)
  Cypher.with(:p).call_in_transactions(inner, 2, p)

  # raw fragments take plain values and sort items
  Cypher.raw('($E + $E) + \$E', Cypher.parameter(:summand1), 2)
  Statement.builder.raw_clause('RETURN $E', 1)
  Statement.builder.raw_clause(RawExpression.new(['ORDER BY ', Cypher.property(:n, :a).descending]))

  # element functions accept a name standing for the element
  Cypher.relationships(p)
  Cypher.nodes(p)
  Cypher.length(p)
  Cypher.type(x)
  Cypher.labels(x)
  Cypher.start_node(x)
  Cypher.end_node(x)
  Cypher.element_id(x)
  Cypher.id(x)

  # the generated-names flags constant feeds the configuration
  flags = Renderer::Configuration::GENERATED_NAMES
  Renderer::Configuration.new_config.with_generated_names(flags - [:entity_names]).build
  Renderer::Configuration.new_config.with_generated_names(flags).build
end
