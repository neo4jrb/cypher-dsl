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
    end
  end
end
