# frozen_string_literal: true

# Ruby-only, no upstream counterpart: regression cases for issues of this repository
# (neo4jrb/cypher-dsl), named after their GitHub issue numbers.
module CypherDSL
  RSpec.describe 'GitHub issues (Ruby repository)' do
    let(:n) { Cypher.any_node(:n) }

    describe 'gh1: WITH alias dropped from a relationship predicate' do
      it 'keeps the alias of the WITH in a pattern condition on that WITH' do
        cypher = Cypher.match(n).with(n.as(:m))
                       .where(Cypher.any_node(:m).relationship_to(Cypher.any_node))
                       .returning(:m).build.cypher
        expect(cypher).to eq('MATCH (n) WITH n AS m WHERE (m)-->() RETURN m')
      end

      it 'keeps the alias when the aliased node carries labels' do
        person = Cypher.node('Person').named(:p)
        cypher = Cypher.match(person).with(person.as(:m))
                       .where(Cypher.any_node(:m).relationship_to(Cypher.node('Movie'), 'ACTED_IN'))
                       .returning(:m).build.cypher
        expect(cypher).to eq('MATCH (p:`Person`) WITH p AS m WHERE (m)-[:`ACTED_IN`]->(:`Movie`) RETURN m')
      end

      it 'still knows the names of the part the WITH ends' do
        m = Cypher.any_node(:m)
        cypher = Cypher.match(n, m).with(n.as(:x), m)
                       .where(n.relationship_to(m))
                       .returning(:x).build.cypher
        expect(cypher).to eq('MATCH (n), (m) WITH n AS x, m WHERE (n)-->(m) RETURN x')
      end

      it 'keeps the alias next to the whole scope when the WITH also projects *' do
        cypher = Cypher.match(n).with(Cypher.asterisk, n.as(:m))
                       .where(Cypher.any_node(:m).relationship_to(n))
                       .match(Cypher.any_node(:o))
                       .where(Cypher.any_node(:m).relationship_to(n).relationship_to(Cypher.any_node(:o)))
                       .returning(:m).build.cypher
        expect(cypher).to eq('MATCH (n) WITH *, n AS m WHERE (m)-->(n) MATCH (o) WHERE (m)-->(n)-->(o) RETURN m')
      end

      it 'forgets the alias after a later WITH that does not carry it' do
        cypher = Cypher.match(n).with(n.as(:m)).with(Cypher.count(Cypher.asterisk).as(:c))
                       .match(Cypher.any_node(:o))
                       .where(Cypher.any_node(:m).relationship_to(Cypher.any_node(:o)))
                       .returning(:c).build.cypher
        expect(cypher).to eq('MATCH (n) WITH n AS m WITH count(*) AS c MATCH (o) WHERE ()-->(o) RETURN c')
      end

      it 'keeps the alias in a pattern condition of a later WHERE' do
        cypher = Cypher.match(n).with(n.as(:m)).match(Cypher.any_node(:o))
                       .where(Cypher.any_node(:m).relationship_to(Cypher.any_node(:o)))
                       .returning(:m).build.cypher
        expect(cypher).to eq('MATCH (n) WITH n AS m MATCH (o) WHERE (m)-->(o) RETURN m')
      end

      # The following cases were contributed in PR #3 (closed in favour of PR #2).
      context 'with the cases of PR #3' do
        let(:condition) { Cypher.any_node(:m).relationship_to(Cypher.any_node) }
        let(:statement) { Cypher.match(n).with(n.as(:m)).where(condition).returning(:m).build }

        it 'keeps aliases projected with distinct' do
          cypher = Cypher.match(n).with_distinct(n.as(:m)).where(condition).returning(:m).build.cypher
          expect(cypher).to eq('MATCH (n) WITH DISTINCT n AS m WHERE (m)-->() RETURN m')
        end

        it 'keeps projected relationship aliases in relationship predicates' do
          relationship = n.relationship_to(Cypher.any_node, 'KNOWS').named(:r)
          predicate = n.relationship_to(Cypher.any_node).named(:s)
          cypher = Cypher.match(relationship).with(n, relationship.as(:s)).where(predicate).returning(:s).build.cypher
          expect(cypher).to eq('MATCH (n)-[r:`KNOWS`]->() WITH n, r AS s WHERE (n)-[s]->() RETURN s')
        end

        it 'resolves generated aliases before rendering where' do
          config = Renderer::Configuration.new_config.with_generated_names(true).build
          expect(Renderer.get_renderer(config).render(statement))
            .to eq('MATCH (v0) WITH v0 AS v1 WHERE (v1)-->() RETURN v1')
        end

        it 'escapes projected aliases in relationship predicates' do
          name = 'node alias'
          predicate = Cypher.any_node(name).relationship_to(Cypher.any_node)
          cypher = Cypher.match(n).with(n.as(name)).where(predicate).returning(Cypher.name(name)).build.cypher
          expect(cypher).to eq('MATCH (n) WITH n AS `node alias` WHERE (`node alias`)-->() RETURN `node alias`')
        end

        it 'preserves the where line when pretty printing' do
          config = Renderer::Configuration.new(pretty_print: true)
          expect(Renderer.get_renderer(config).render(statement)).to eq("MATCH (n)\nWITH n AS m\nWHERE (m)-->()\nRETURN m")
        end
      end
    end
  end
end
