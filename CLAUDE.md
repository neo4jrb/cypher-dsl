# Working conventions for cypher-dsl (Ruby)

## What this is

A Ruby implementation of the *design* of Neo4j's Cypher-DSL for Java, not a
line-by-line port. The reference source is a full clone of the Java project at
`~/projects/cypher-dsl-java` (module `neo4j-cypher-dsl`, package
`org.neo4j.cypherdsl.core`). Read it for semantics; write idiomatic Ruby.

## Method: tests first, translated from upstream

- Specs are translated from
  `neo4j-cypher-dsl/src/test/java/org/neo4j/cypherdsl/core/*.java`, feature
  group by feature group (the nested classes of `CypherIT.java` are the map).
  Keep the expected Cypher strings **verbatim**; they are the contract.
- One spec file per upstream test class or nested group, named after it
  (`CypherIT` → `spec/cypher_dsl/cypher_it/<nested_group>_spec.rb`). The
  `describe` string keeps the upstream class names (`'CypherIT / Conditions'`).
- Example names are the upstream test method names split into lowercase
  words, with a leading "should" dropped as RSpec style wants:
  `shouldRenderMergeWithoutReturn` → `it 'renders merge without return'`,
  `unrelatedNodes` → `it 'unrelated nodes'`. That reads like RSpec and still
  maps one to one onto the Java test.
- Record what was skipped and why at the top of each spec file (Java-only
  constructs, QueryDSL adapter, native tests, etc.).

## API rules

- Public names mirror the Java API in snake_case: `Cypher.node`, `.named`,
  `.relationship_to`, `.is_equal_to`, `.returning`, `.build`. Add Ruby sugar
  (`==`, `>`, `&`) only as aliases on top, never instead.
- Symbols and Strings are interchangeable for names; the renderer normalises.
- Everything is immutable: builder methods return new objects, `Statement`
  and all AST nodes are frozen.
- Rendering defaults match Cypher-DSL: identifiers are backtick-escaped
  (`(n:`Person`)`), literals render inline, parameters only when asked for.
  Both are `Renderer::Configuration` options.
- Runtime dependency is Zeitwerk only. No ActiveSupport.
- Zeitwerk one-class-per-file; constant `CypherDSL` is an inflection.

## Static checks

Every PR runs, each as its own GitHub workflow: `rspec` (3.4, latest MRI,
JRuby) plus a `diff-coverage` gate, `rubocop` (with rubocop-performance and
rubocop-rspec), `reek` against the `.reek.yml` baseline, and `rbs validate` +
`steep check` of `lib/` against `sig/`. Locally: `bundle exec rake static`, or
`bundle exec rake` for specs and checks together.

- RuboCop and Reek are pinned at the patch level in the Gemfile; bumping them
  may add cops or detectors, so bump deliberately and refresh the baseline.
- Reek's `.reek.yml` grandfathers the smells that existed when it was
  introduced. New code must not add smells; shrink the file, never grow it
  (`bundle exec reek --todo lib` regenerates it after a cleanup).
- `sig/` mirrors `lib/`, one `.rbs` per `.rb`, and is shipped in the gem. Every
  new or changed public method needs its signature updated; Steep runs in
  strict mode, so `untyped` needs a `# untyped: <reason>` comment. Third-party
  signatures come from `rbs_collection.yaml` (`bundle exec rbs collection
  install`, lock file committed, install dir git-ignored); `sig/manifest.yaml`
  declares the stdlib signatures the shipped `sig/` needs.
- `typecheck/usage.rb` is a Steep target of public API calls that must type
  check. Signatures must accept everything the method accepts at runtime;
  prefer overloads over unions so the result type stays specific, and add the
  call that exposed a too-narrow signature to that file.
- Coverage: `COVERAGE=1 bundle exec rspec` (MRI only) writes
  `coverage/.resultset.json`; `rake coverage:enforce` fails on any executable
  line added or changed under `lib/` vs `origin/main` that no test hit.

## Commits and releases

- Conventional Commits for every commit and PR title; PRs are squash-merged.
- `feat`/`fix`/`perf` appear in the changelog; `chore`, `docs`, `test`,
  `refactor`, `ci` do not.
- Never merge PRs; the maintainer merges.

## Releasing (pre-releases on rubygems.org)

Work happens directly on `main`. For a release:

1. Bump `lib/cypher_dsl/version.rb` and the install line in `README.md`.
2. Move the `[Unreleased]` entries of `CHANGELOG.md` into a dated version
   section and update the compare links at the bottom.
3. `bundle install` (the lockfile is gitignored), `bundle exec rspec`,
   `gem build cypher-dsl.gemspec`.
4. Commit as `chore(release): vX.Y.Z`, push `main`, push an annotated tag
   `vX.Y.Z`, wait for CI.
5. The maintainer pushes the `.gem` to rubygems.org themselves (MFA). Never
   run `gem push`.

## Status and roadmap

- Translated and green: `CypherIT` (all nested groups), `ProcedureCalls`,
  `Subqueries` (+ GQL), `ParameterIT`, `IssueRelatedIT` 1–6, `FunctionsIT`,
  `HintsIT`, `LoadCSVIT`, `DialectIT`, `UseIT`, `ExpressionsIT`,
  `IdentifiableExpressionsIT`, `Cypher5IT`, `LabelsTests`, `SearchTests`,
  `VectorTests`, `ConfigurableRendererTests` and the small unit-test classes
  (literals, escaping, preconditions, `to_s`, visitors).
- Deliberately not ported: `DurationLiteralTests` (no Ruby duration type),
  `TreeNode`, `BuiltInFunctions`, `PackageAndAPIStructure`,
  `ReflectiveVisitor`, `ForeignAdapter` and the QueryDSL adapter. The
  `StatementCatalog` exposes only parameters and identifiable expressions
  (no labels/properties/filters/relations/literals catalog).
- Design choice that differs from Java: `nil` arguments coerce to the `NULL`
  literal instead of raising.
- Ruby-only additions exist for host DSLs that still build strings:
  `Cypher.raw` as pattern element / condition / SET operation,
  `StatementBuilder#raw_clause`, `Renderer#render_fragment`,
  `ConflictingParametersException` carrying `{name => Set[values]}`.
- Main consumer: [activegraph](https://github.com/neo4jrb/activegraph)
  (`ActiveGraph::Core::Query`, `QueryProxy`, association patterns) since its
  PR #1753, requiring `>= 0.1.0.alpha.3`. Keep those entry points stable.
- A whole property map as a parameter is expressed the Java way, through
  `node.set(parameter)` / `node.mutate(parameter)` (`SET n = $props`,
  `SET n += $props`), not as pattern properties: `MapExpression.of` rejects
  a lone `Parameter`, as Java does, and activegraph's factories use the SET
  form. Only add the pattern form if a consumer needs byte-identical
  `CREATE (n:Label $props)` text.
- Parameter naming is the caller's job, as in Java: `Cypher.union` and
  `Cypher.call(statement)` merge the parameters of the parts and raise
  `ConflictingParametersException` on a clash. Do not add a renaming pass
  to the DSL; a host that builds union / `CALL {}` branches independently
  must give them unique names when it creates them (activegraph does this
  with a namespaced parameter registry, `Core::Query#params_namespace`).
- Schema DDL (constraints, indexes) has no model at all, neither here nor in
  Java; activegraph keeps those templates as strings.

## Licensing

Ruby code is MIT. Translated specs are a derivative of Apache-2.0 code: keep
`NOTICE` accurate and do not copy Java *implementation* code verbatim.
