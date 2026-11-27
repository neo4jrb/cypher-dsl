# frozen_string_literal: true

# Translated from FunctionsTests.java.
#
# Adapted: Java reflects over the single-argument methods of `Functions`; here every public
# one-argument method of {Functions} (except `reduce`, which starts a reduction) is called with
# a symbolic name and must yield a function named after the method (`to_upper` → `toUpper`,
# `graph_by_name` → `graph.byName`, `_distinct` dropped). The null-argument preconditions have
# no counterpart: `nil` is the NULL literal in this port.
module CypherDSL
  RSpec.describe 'FunctionsTests' do
    functions_to_test = Functions.public_instance_methods(false)
                                 .select { |name| Functions.instance_method(name).arity == 1 }
                                 .reject { |name| name == :reduce }
                                 .sort

    def expected_function_name(method)
      words = method.to_s.delete_suffix('_distinct').split('_')
      camel = words.first + words.drop(1).map(&:capitalize).join
      camel.start_with?('graph') ? "graph.#{camel[5].downcase}#{camel[6..]}" : camel
    end

    functions_to_test.each do |method|
      it "function invocations should be created(#{method})" do
        invocation = Cypher.public_send(method, SymbolicName.of('Undef'))
        expect(invocation).to be_a(FunctionInvocation)
        expect(invocation.function_name).to eq(expected_function_name(method))
      end
    end

    describe 'coalesce' do
      it 'preconditions should be asserted' do
        message = 'The expression for coalesce() is required.'
        expect { Cypher.coalesce }.to raise_error(ArgumentError, message)
        expect { Cypher.coalesce([]) }.to raise_error(ArgumentError, message)
      end

      it 'creates correct invocation' do
        invocation = Cypher.coalesce(Cypher.name(:x))
        expect(invocation.function_name).to eq('coalesce')
      end
    end
  end
end
