# frozen_string_literal: true

module CypherDSL
  # `SEARCH movie IN (VECTOR INDEX moviePlots FOR $vector WHERE … LIMIT 4) SCORE AS score`,
  # attached to a MATCH clause. Built with
  # `Cypher.search(:movie).in('moviePlots').for_vector(vector).where(…).limit(4).score(:s).build`.
  class Search
    SUPPORTED_VECTORS = [VectorLiteral, ListExpression, Parameter, Property].freeze

    attr_reader :name, :index_name, :vector, :predicates, :top_k, :score_name

    def initialize(name:, index_name:, vector:, predicates:, top_k:, score_name:)
      @name = name
      @index_name = index_name
      @vector = vector
      @predicates = predicates.freeze
      @top_k = top_k
      @score_name = score_name
      freeze
    end

    # The search rendered on its own with the default renderer.
    def cypher = Renderer.default.render_fragment(self)
    alias to_s cypher

    # The ongoing definition; every step returns a new builder.
    class Builder
      def initialize(name, index_name: nil, vector: nil, predicates: [], top_k: nil, score_name: nil)
        raise ArgumentError, 'Name is required' if name.nil?

        @name = name
        @index_name = index_name
        @vector = vector
        @predicates = predicates
        @top_k = top_k
        @score_name = score_name
        freeze
      end

      def in(index_name)
        if index_name.nil? || index_name.to_s.strip.empty?
          raise ArgumentError, 'The index name must not be null or empty'
        end

        with(index_name: index_name.to_s)
      end

      def for_vector(vector)
        raise ArgumentError, 'Vector is required' if vector.nil?
        unless Search::SUPPORTED_VECTORS.any? { |type| vector.is_a?(type) }
          raise ArgumentError, "Unsupported vector expression #{vector.inspect}"
        end

        with(vector:)
      end

      # Only comparisons; several are combined with AND.
      def where(*predicates)
        predicates = predicates.flatten
        raise ArgumentError, 'A predicate is required' if predicates.empty? || predicates.any?(nil)
        raise ArgumentError, 'Only comparison conditions are supported' unless predicates.all?(Comparison)

        with(predicates:)
      end

      def limit(top_k)
        raise ArgumentError, 'topK must be greater than or equal to 0' if top_k.negative?

        with(top_k:)
      end

      def score(name) = with(score_name: SymbolicName.of(name))

      def build
        # @type ivar @index_name: String
        # @type ivar @vector: vector
        raise ArgumentError, 'The index name is required' if @index_name.nil?
        raise ArgumentError, 'The vector is required' if @vector.nil?

        Search.new(name: @name, index_name: @index_name, vector: @vector, predicates: @predicates, top_k: @top_k,
                   score_name: @score_name)
      end

      private

      def with(**changes)
        options = { index_name: @index_name, vector: @vector, predicates: @predicates, top_k: @top_k,
                    score_name: @score_name }.merge(changes)
        Builder.new(@name, **options)
      end
    end
  end
end
