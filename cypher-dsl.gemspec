# frozen_string_literal: true

require_relative 'lib/cypher_dsl/version'

Gem::Specification.new do |spec|
  spec.name = 'cypher-dsl'
  spec.version = CypherDSL::VERSION
  spec.authors = ['Heinrich Klobuczek']
  spec.email = ['heinrich@mail.com']

  spec.summary = 'A Ruby DSL (builder) for the Cypher query language'
  spec.description = 'An immutable, part-aware builder and renderer for Cypher statements, ' \
                     'modelled on the design of Neo4j\'s Cypher-DSL for Java.'
  spec.homepage = 'https://github.com/neo4jrb/cypher-dsl'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*.rb', 'sig/**/*.rbs', 'sig/manifest.yaml',
                   'README.md', 'CHANGELOG.md', 'LICENSE.txt', 'NOTICE']
  spec.require_paths = ['lib']

  spec.add_dependency 'zeitwerk', '~> 2.6'
end
