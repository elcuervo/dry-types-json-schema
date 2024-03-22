# frozen_string_literal: true

module Dry
  module Types
    class JSONSchema
      UnknownPredicateError = Class.new(StandardError)

      EMPTY_HASH = {}.freeze
      IDENTITY = ->(v, _) { v }.freeze
      TO_INTEGER = ->(v, _) { v.to_i }.freeze
      TO_TYPE = ->(v, _) { CLASS_TO_TYPE.fetch(v.to_s.to_sym) }.freeze

      ARRAY_PREDICATE_OVERRIDE = {
        min_size?: :min_items?,
        max_size?: :max_items?,
      }.freeze

      CLASS_TO_TYPE = {
        String:     :string,
        Integer:    :integer,
        TrueClass:  :boolean,
        FalseClass: :boolean,
        NilClass:   :null,
        BigDecimal: :number,
        Hash:       :object,
        Array:      :array,
      }.freeze

      PREDICATE_TO_TYPE = {
        type?:      { type: TO_TYPE },
        min_size?:  { minLength: TO_INTEGER },
        min_items?: { minItems: TO_INTEGER },
        max_size?:  { maxLength: TO_INTEGER },
        max_items?: { maxItems: TO_INTEGER },
        min?:       { maxLength: TO_INTEGER },
        gt?:        { exclusiveMinimum: IDENTITY },
        gteq?:      { minimum: IDENTITY },
        lt?:        { exclusiveMaximum: IDENTITY },
        lteq?:      { maximum: IDENTITY },
      }.freeze

      attr_reader :required

      def initialize(root: false)
        @keys = EMPTY_HASH.dup
        @required = Set.new
        @root = root
      end

      def root? = @root

      def call(ast)
        visit(ast)
      end

      def to_hash
        result = @keys.to_hash
        result[:$schema] = "http://json-schema.org/draft-06/schema#" if root?
        result
      end

      def visit(node, opts = EMPTY_HASH)
        name, rest = node
        public_send(:"visit_#{name}", rest, opts)
      end

      def visit_constrained(node, opts = EMPTY_HASH)
        node.each { |it| visit(it, opts) }
      end

      def visit_constructor(node, opts = EMPTY_HASH)
        type, _ = node

        visit(type, opts)
      end

      def visit_nominal(node, opts = EMPTY_HASH)
        type, _ = node
        type
      end

      def visit_predicate(node, opts = EMPTY_HASH)
        head, tail = node
        (_, type), = tail

        ctx = opts[:key]

        head = ARRAY_PREDICATE_OVERRIDE[head] if opts[:mod]

        definition = PREDICATE_TO_TYPE.fetch(head) do
          raise UnknownPredicateError

          EMPTY_HASH
        end.dup

        definition
          .transform_values! { |v| v.call(type, ctx) }

        return unless definition.any? && ctx

        @keys[ctx] ||= {}
        @keys[ctx].merge!(definition)
      end

      def visit_sum(node, opts = EMPTY_HASH)
        *types, meta = node

        # FIXME: cleaner way to generate individual type
        #
        process = -> (type) do
          self.class.new
            .tap { |target| target.visit(type, opts) }
            .to_hash
            .values
            .first
        end

        result = types.map(&process).uniq

        return @keys[opts[:key]] = result.first if result.count == 1

        return @keys[opts[:key]] = { anyOf: result } unless opts[:array]

        @keys[opts[:key]] = {
          type: :array,
          items: { anyOf: result }
        }
      end

      def visit_and(node, opts = EMPTY_HASH)
        left, right = node
        (_, (action, ((_, left_type), ))) = left

        visit(left, opts)

        return visit(right, opts.merge(mod: true)) if left_type == ::Array

        visit(right, opts)
      end

      def visit_hash(node, opts = EMPTY_HASH)
        part, meta = node

        @keys[opts[:key]] = { type: :object }
      end

      def visit_array(node, opts = EMPTY_HASH)
        type, meta = node

        visit(type, opts.merge(array: true))
      end

      def visit_schema(node, opts = EMPTY_HASH)
        keys, options, meta = node

        target = self.class.new

        keys.each { |fragment| target.visit(fragment, opts) }

        definition = { type: :object, properties: target.to_hash }.tap do |hash|
          hash[:required] = target.required.to_a if target.required.any?
        end

        @keys.merge!(definition)
      end

      def visit_key(node, opts = EMPTY_HASH)
        name, required, rest = node

        @required << name if required

        visit(rest, opts.merge(key: name))
      end
    end

    module Builder
      def json_schema(root: false)
        compiler = JSONSchema.new(root: root)
        compiler.call(to_ast)
        compiler.to_hash
      end
    end
  end
end
