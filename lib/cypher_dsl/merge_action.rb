# frozen_string_literal: true

module CypherDSL
  # `ON CREATE SET …` / `ON MATCH SET …` attached to a MERGE.
  MergeAction = Data.define(:type, :operations) do
    # @implements MergeAction
    # `MergeAction.of(:on_create, set_clause)`; the type may also be given as `:ON_CREATE`.
    def self.of(type, set_clause)
      new(type: type.to_s.downcase.to_sym, operations: set_clause.operations)
    end
  end
end
