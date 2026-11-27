# Contributing

Issues and pull requests are welcome at
[neo4jrb/cypher-dsl](https://github.com/neo4jrb/cypher-dsl). Pull requests are
squash-merged, so the PR title is the commit message: use
[Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`,
`test:`, `docs:`, `chore:`). `feat` and `fix` entries also go into
`CHANGELOG.md` under *Unreleased*.

## Setup

```sh
bundle install
bundle exec rbs collection install   # third-party signatures for steep
bundle exec rake                      # specs and every static check
```

## What CI checks

Each check is its own workflow, so a failure names the tool at fault.

| Workflow | Command | Gate |
| --- | --- | --- |
| Test | `bundle exec rspec` on Ruby 3.4, latest MRI and JRuby | all examples pass |
| Test / diff-coverage | `COVERAGE=1 bundle exec rspec` then `rake coverage:enforce` | every executable line added or changed under `lib/` is hit by a test |
| RuboCop | `bundle exec rubocop` | no offenses (`.rubocop.yml`, rubocop-performance, rubocop-rspec) |
| Reek | `bundle exec reek lib` | no code smell beyond the `.reek.yml` baseline |
| Types | `bundle exec rbs -I sig validate` and `bundle exec steep check` | `sig/` is valid, `lib/` and `typecheck/usage.rb` type check against it (strict) |

Run them all locally with `bundle exec rake static` (on JRuby without the
type checks, whose gems are MRI-only).

## Specs

Specs are translated from the Java Cypher-DSL test suite; the expected Cypher
strings are the contract and stay verbatim. One spec file per upstream test
class, example names are the upstream method names in words. Regression cases
for issues of this repository live in `spec/cypher_dsl/github_issues_spec.rb`.

## Type signatures

`sig/` mirrors `lib/` with one `.rbs` per `.rb` and is shipped in the gem.
Shared type aliases (`expression_like`, `name_like`, `condition_like`,
`pattern_element`, `Clauses::clause`) live in `sig/cypher_dsl.rbs`. When you
add or change a public method, update its signature; Steep runs in strict
mode, so an `untyped` needs a `# untyped: <reason>` comment above it.

Steep checks `lib/` against the signatures, which proves the implementation
matches them but not that they accept every call the DSL supports. For that,
`typecheck/usage.rb` holds public API calls that must type check, and it is a
second Steep target. When a signature turns out narrower than the method (a
reviewer or a consumer hits a supported call Steep rejects), widen the
signature, usually with overloads so the result type stays specific, and add
the call there.

`sig/manifest.yaml` names the standard library signatures the shipped `sig/`
depends on (`date`, `time`), for `rbs collection` in projects using the gem.

## Baselines

RuboCop and Reek are pinned at the patch level in the `Gemfile`. A minor bump
can add cops or detectors and turn CI red, so bump them on purpose and refresh
the Reek baseline with `bundle exec reek --todo lib` only after cleaning up,
never to hide a new smell.
