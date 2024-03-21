# frozen_string_literal: true

module Dry
  module Types
    class JSONSchema
      EMPTY_HASH = {}.freeze
      IDENTITY = ->(v, _) { v }.freeze
      TO_INTEGER = ->(v, _) { v.to_i }.freeze

      PREDICATE_TO_TYPE = {
        String: { type: :string },
        Hash: { type: :object, properties: {} }
      }.freeze

      def initialize
        @keys = EMPTY_HASH.dup
      end

      def call(ast)
        binding.pry
        visit(ast)
      end

      def to_hash
        @keys.to_hash
      end

      def visit(node, opts = EMPTY_HASH)
        name, rest = node
        public_send(:"visit_#{name}", rest, opts)
      end

      def visit_constrained(node, opts = EMPTY_HASH)
        node.each { |it| visit(it, opts) }
      end

      def visit_nominal(node, opts = EMPTY_HASH)
        type, _ = node
        type
      end

      def visit_predicate(node, opts = EMPTY_HASH)
        name, ((_, type), input) = node

        if name == :type?
          definition = PREDICATE_TO_TYPE[type.to_s.to_sym]
          ctx = opts[:key]

          @keys[ctx] = definition
        end
      end

      def visit_hash(node, opts = EMPTY_HASH)
        @keys.merge!({ type: :object, properties: {} })
      end

      def visit_schema(node, opts = EMPTY_HASH)
        keys, options, meta = node

        keys.each { |fragment| visit(fragment, opts) }
      end

      def visit_key(node, opts = EMPTY_HASH)
        name, required, rest = node

        visit(rest, opts.merge(key: name))
      end
    end

    module Builder
      def json_schema
        compiler = JSONSchema.new
        compiler.call(to_ast)
        compiler.to_hash
      end
    end
  end
end
