# frozen_string_literal: true

module Dry
  module Types
    # The `JSONSchema` class is responsible for converting dry-types type definitions into JSON Schema definitions.
    # This class enables the transformation of complex type constraints into a standardized JSON Schema format,
    # facilitating interoperability with systems that utilize JSON Schema for validation.
    #
    class JSONSchema
      # Error raised when an unknown predicate is encountered during schema generation.
      #
      UnknownPredicateError = Class.new(StandardError)

      # Constant definitions for various lambdas and mappings used throughout the JSON schema conversion process.
      #
      EMPTY_HASH = {}.freeze
      IDENTITY = ->(v, _) { v }.freeze
      TO_INTEGER = ->(v, _) { v.to_i }.freeze
      INSPECT = ->(v, _) { v.inspect }.freeze
      TO_TYPE = ->(v, _) { CLASS_TO_TYPE.fetch(v.to_s.to_sym) }.freeze

      # Metadata annotations and allowed types overrides for schema generation.
      #
      ANNOTATIONS = %i[title description].freeze
      ALLOWED_TYPES_META_OVERRIDES = ANNOTATIONS.dup.concat([:format]).freeze

      # Mapping for array predicate overrides.
      #
      ARRAY_PREDICATE_OVERRIDE = {
        min_size?: :min_items?,
        max_size?: :max_items?
      }.freeze

      # Mapping of Ruby classes to their corresponding JSON Schema types.
      #
      CLASS_TO_TYPE = {
        String:     :string,
        Integer:    :integer,
        TrueClass:  :boolean,
        FalseClass: :boolean,
        NilClass:   :null,
        BigDecimal: :number,
        Float:      :number,
        Hash:       :object,
        Array:      :array,
        Date:       :string,
        DateTime:   :string,
        Time:       :string
      }.freeze


      # Additional properties for specific types, such as formatting options.
      #
      EXTRA_PROPS_FOR_TYPE = {
        Date:     { format: :date },
        Time:     { format: :time },
        DateTime: { format: :"date-time" }
      }.freeze

      # Mapping of predicate methods to their corresponding JSON Schema expressions.
      #
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
        format?:    { format: INSPECT }
      }.freeze

      # @return [Set] the set of required keys for the JSON Schema.
      #
      attr_reader :required


      # Initializes a new instance of the JSONSchema class.
      # @param root [Boolean] whether this schema is the root schema.
      # @param loose [Boolean] whether to ignore unknown predicates.
      #
      def initialize(root: false, loose: false)
        @keys = EMPTY_HASH.dup
        @required = Set.new
        @root = root
        @loose = loose
      end

      # Checks if the schema is the root schema.
      # @return [Boolean] true if this is the root schema; otherwise, false.
      #
      def root?  = @root

      # Checks if unknown predicates are ignored.
      # @return [Boolean] true if ignoring unknown predicates; otherwise, false.
      #
      def loose? = @loose

      # Processes the abstract syntax tree (AST) and generates the JSON Schema.
      # @param ast [Array] the abstract syntax tree representing type definitions.
      # @return [void]
      #
      def call(ast)
        visit(ast)
      end

      # Converts the internal schema representation into a hash.
      # @return [Hash] the JSON Schema as a hash.
      #
      def to_hash
        result = @keys.to_hash
        result[:$schema] = "http://json-schema.org/draft-06/schema#" if root?
        result
      end

      # Visits a node in the abstract syntax tree and processes it according to its type.
      # @param node [Array] the node to process.
      # @param opts [Hash] optional parameters for node processing.
      # @return [void]
      #
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
        type, meta = node

        if opts.fetch(:key, false)
          if meta.any?
            @keys[opts[:key]] ||= {}
            @keys[opts[:key]].merge!(meta.slice(*ALLOWED_TYPES_META_OVERRIDES))
          end
        else
          @keys.merge!(type: CLASS_TO_TYPE[type.to_s.to_sym])
          @keys.merge!(meta.slice(*ALLOWED_TYPES_META_OVERRIDES)) if meta.any?
        end
      end

      def visit_predicate(node, opts = EMPTY_HASH)
        head, ((_, type),) = node
        ctx = opts[:key]

        head = ARRAY_PREDICATE_OVERRIDE.fetch(head) if opts[:left_type] == ::Array

        definition = PREDICATE_TO_TYPE.fetch(head) do
          raise UnknownPredicateError, head unless loose?

          EMPTY_HASH
        end.dup

        definition.transform_values! { |v| v.call(type, ctx) }

        return unless definition.any? && ctx

        if (extra = EXTRA_PROPS_FOR_TYPE[type.to_s.to_sym])
          definition = definition.merge(extra)
        end

        @keys[ctx] ||= {}
        @keys[ctx].merge!(definition)
      end

      def visit_sum(node, opts = EMPTY_HASH)
        *types, _ = node

        # FIXME: cleaner way to generate individual types
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
        (_, (_, ((_, left_type),))) = left

        visit(left, opts)
        visit(right, opts.merge(left_type: left_type))
      end

      def visit_hash(node, opts = EMPTY_HASH)
        _part, _meta = node

        @keys[opts[:key]] = { type: :object }
      end

      def visit_array(node, opts = EMPTY_HASH)
        type, meta = node

        visit(type, opts.merge(array: true))

        @keys[opts[:key]].merge!(meta.slice(*ANNOTATIONS)) if meta.any?
      end

      def visit_schema(node, opts = EMPTY_HASH)
        keys, _, meta = node

        target = self.class.new

        keys.each { |fragment| target.visit(fragment, opts) }

        definition = { type: :object, properties: target.to_hash }

        definition[:required] = target.required.to_a if target.required.any?
        definition.merge!(meta.slice(*ANNOTATIONS))  if meta.any?

        @keys.merge!(definition)
      end

      def visit_key(node, opts = EMPTY_HASH)
        name, required, rest = node

        @required << name if required

        visit(rest, opts.merge(key: name))
      end
    end

    # The `Builder` module provides a method to generate a JSON Schema hash from dry-types definitions.
    #
    module Builder
      # @overload json_schema(options = {})
      #   @param options [Hash] Initialization options passed to `JSONSchema.new`
      #   @return [Hash] The generated JSON Schema as a hash.
      #
      def json_schema(*)
        compiler = JSONSchema.new(*)
        compiler.call(to_ast)
        compiler.to_hash
      end
    end
  end
end
