# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- A name projected by `WITH` is visible to that clause's own `WHERE`, so a pattern condition
  keeps it: `WITH n AS m WHERE (m)-->()` no longer renders as `WHERE ()-->()` (#1).

## [0.1.0.alpha.3] - 2026-11-01

The release activegraph's `ActiveGraph::Core::Query` builds on.

### Added

- Raw fragments for host DSLs built on strings (Ruby-only, no Java counterpart): `Cypher.raw`
  is accepted as a pattern element in MATCH/CREATE/MERGE, as a condition (also as operand of
  `and`/`or`/`xor`/`not`), as a complete SET / ON CREATE SET / ON MATCH SET operation, and
  `StatementBuilder#raw_clause(format, *args)` renders a whole clause verbatim.
- Raw operands of a compound condition are parenthesised unless they already form one group,
  so `Cypher.raw('a OR b').as_condition.and(c)` renders `((a OR b) AND c)`.

## [0.1.0.alpha.2] - 2026-11-01

Second pre-release. The whole upstream core test suite that applies to Ruby is now
translated (1067 examples): all remaining integration tests (HintsIT, LoadCSVIT, DialectIT,
SubqueriesGQLIT, UseIT, ExpressionsIT, IdentifiableExpressionsIT, Cypher5IT, labels, search
and vector tests) and the unit tests for literals, escaping, preconditions and `toString`.
Not translated: `DurationLiteralTests` (no duration type in Ruby's standard library), the
Java-only reflection, package-structure and foreign-adapter tests, and the QueryDSL adapter.

### Added

- Planner hints: `using_index`, `using_index_seek`, `using_scan`, `using_join_on` (HintsIT).
- LOAD CSV: `with_field_terminator`, `Cypher.using_periodic_commit`, `linenumber()`, `file()`.
- All Java dialects including `NEO4J_5_26`, `NEO4J_5_CYPHER_5`, `NEO4J_5_CYPHER_25` with their
  `CYPHER 5` / `CYPHER 25` prefixes; `NEO4J_5_DEFAULT_CYPHER` is the default.
- Label expressions (`Labels.exactly/all/any`, `and`, `or`, `negate`, `conjunction_with`),
  dynamic labels `n:$($labels)` on Neo4j 5.26+, `disable_dynamic_labels`.
- Vector `SEARCH` clauses (`Cypher.search`) and `Cypher.vector` literals.
- Generated names (`with_generated_names`) and `StatementCatalog#renamed_parameters`.
- `Cypher.exists(property)` renders `exists()` on Neo4j 4 and `IS NOT NULL` afterwards;
  `shortestPath()` / `allShortestPaths()` on Neo4j 4 and 5.
- `StatementCatalog#identifiable_expressions`: the items of the final `RETURN` or `YIELD`
  (SubqueriesGQLIT); also on the builder after a `WITH`/`RETURN` (IdentifiableExpressionsIT).
- `Cypher.raw(format, *args)` with `$E` placeholders and `\$E` escapes (RawLiteralTests).
- `COUNT { pattern WHERE … }` and `Cypher.subquery_with(…).count(…)` (ExpressionsIT).
- `Cypher.use` validates nested `USE` and `EXPLAIN`/`PROFILE` inner statements and wraps
  names, literals and parameters in `graph.byName(…)`; `Statement#explain` / `#profile` (UseIT).
- `Date`, `Time` and `DateTime` literals render as `date(…)` / `datetime(…)`.
- `Cypher.format`, `Cypher.quote`, `Cypher.has_labels_or_type`, `Cypher.sort(expr, direction)`,
  `Property#name` / `#referenced_as`, `Configuration#==`, `to_s` on expressions and patterns
  (the plain Cypher, as the Java `toString`).
- Upstream preconditions: empty labels, unnamed nodes in `SET`/`+=`, missing patterns or
  return items, non-updating clauses inside `FOREACH`, `DISTINCT` on non-aggregates,
  unsupported literal types.

### Fixed

- Node and relationship names that need quoting (e.g. containing a backtick) are now
  escaped inside patterns, not only where they are used as expressions.
- A `CALL { }` following a leading `USE` renders as `CALL () { }`.
- A `nil` additional label in `Cypher.node` raises `An empty label is not allowed.` instead of being
  dropped silently; symbols and strings are validated alike.

### Changed

- The default dialect is `NEO4J_5_DEFAULT_CYPHER` (was `NEO4J_5_23`); the only difference
  is that dynamic label expressions render as such.
- Name escaping follows upstream exactly: ``` stands for a backtick, doubled
  backticks are collapsed before escaping, and an already quoted name is quoted again.
  String literals escape double quotes as well as single quotes and backslashes.

## [0.1.0.alpha.1] - 2026-10-31

First pre-release, reserving the gem name. A Ruby reimplementation of the design of
[Neo4j's Cypher-DSL for Java](https://github.com/neo4j/cypher-dsl), built test-first from
specs translated from its test suite (CypherIT, ProcedureCalls, Subqueries, parameter
collection, IssueRelatedIT, FunctionsIT).

### Added

- Immutable statement builder with MATCH/OPTIONAL MATCH, WHERE, WITH, RETURN, ORDER BY,
  SKIP/LIMIT, UNWIND, CREATE, MERGE (ON CREATE/ON MATCH), SET, REMOVE, DELETE, FOREACH,
  CALL procedures (YIELD, YIELD *), CALL subqueries (imports, IN TRANSACTIONS), LOAD CSV,
  USE, UNION/UNION ALL, FINISH, EXPLAIN/PROFILE.
- Patterns: nodes, relationships, chains, named paths, quantified path patterns,
  path selectors, label expressions.
- Expressions: literals, parameters, maps, lists, map projections, list and pattern
  comprehensions, list predicates, CASE, reduce(), EXISTS/COUNT/COLLECT subquery
  expressions, the built-in function catalogue.
- Renderer with dialects (Neo4j 4, 5, 5.23+), pretty printing, identifier escaping,
  parameter collection (`Statement#catalog`).

[Unreleased]: https://github.com/neo4jrb/cypher-dsl/compare/v0.1.0.alpha.3...HEAD
[0.1.0.alpha.3]: https://github.com/neo4jrb/cypher-dsl/compare/v0.1.0.alpha.2...v0.1.0.alpha.3
[0.1.0.alpha.2]: https://github.com/neo4jrb/cypher-dsl/compare/v0.1.0.alpha.1...v0.1.0.alpha.2
[0.1.0.alpha.1]: https://github.com/neo4jrb/cypher-dsl/releases/tag/v0.1.0.alpha.1
