module Tagtical
  class Tag < ::ActiveRecord::Base

    attr_accessible :value

    has_many :taggings, :dependent => :destroy, :class_name => 'Tagtical::Tagging'

    scope(:type, lambda do |context, *args|
      Type.cache[Type.send(:sanitize, context)].inject(nil) do |scoping, tag_type|
        scope = tag_type.scoping(*args)
        scoping ? scoping.merge(scope) : scope
      end
    end)

    validates :value, :uniqueness => {:scope => :type}, :presence => true # type is not required, it can be blank

    class_attribute :possible_values
    before_validation :ensure_possible_values
    validate :validate_possible_values

    class_attribute :relevance_range

    ### CLASS METHODS:

    class << self

      def where_any(list, options={})
        char = "%" if options[:wildcard]
        operator = options[:case_insensitive] || options[:wildcard] ?
          (using_postgresql? ? 'ILIKE' : 'LIKE') :
          "="
        conditions = Array(list).map { |tag| ["value #{operator} ?", "#{char}#{tag.to_s}#{char}"] }
        where(conditions.size==1 ? conditions.first : conditions.map { |c| sanitize_sql(c) }.join(" OR "))
      end

      def using_postgresql?
        connection.adapter_name=='PostgreSQL'
      end

      # Use this for case insensitive
      def where_any_like(list, options={})
        where_any(list, options.update(:case_insensitive => true))
      end

      ### CLASS METHODS:

      def find_or_create_with_like_by_value!(value)
        where_any_like(value).first || create!(:value => value)
      end

      # Method used to ensure list of tags for the given Tag class.
      # Returns a hash with the key being the value from the tag list and the value being the saved tag.
      def find_or_create_tags(*tag_list)
        tag_list = [tag_list].flatten
        return {} if tag_list.empty?

        existing_tags = where_any_like(tag_list).all
        tag_list.each_with_object({}) do |value, tag_lookup|
          tag_lookup[detect_comparable(existing_tags, value) || create!(:value => value)] = value
        end
      end

        # Save disc space by not having to put in "Tagtical::Tag" repeatedly
      def sti_name
        Tagtical::Tag==self ? nil : super
      end

      def define_scope_for_type(tag_type)
        scope(tag_type.scope_name, lambda { |*args| type(tag_type.to_s, *args) }) unless respond_to?(tag_type.scope_name)
      end

        # Checks to see if a tags value is present in a set of tags and returns that tag.
      def detect_comparable(objects, value)
        value = comparable_value(value)
        objects.detect { |obj| comparable_value(obj) == value }
      end

      def detect_possible_value(value)
        detect_comparable(possible_values, value) if possible_values
      end

      protected

      def compute_type(type_name)
        type_name.nil? ? Tagtical::Tag : super
      end

      private

      if RUBY_VERSION >= "1.9"
        def comparable_value(str)
          str = str.value if str.is_a?(self)
          str.downcase
        end
      else
        def comparable_value(str)
          str = str.value if str.is_a?(self)
          str.mb_chars.downcase
        end
      end

    end

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(self.class) && value == object.value)
    end

    # Relevance is transferred through "taggings" join.
    def relevance
      (v = self[:relevance]) && v.to_f
    end

    def relevance=(relevance)
      self[:relevance] = relevance
    end

      # Try to sort by the relevance if provided.
    def <=>(tag)
      if (r1 = relevance) && (r2 = tag.relevance)
        r1 <=> r2
      else
        value <=> tag.value
      end
    end

    def to_s
      value
    end

    def inspect
      super.tap do |str|
        str[-1] = ", relevance: #{relevance}>" if relevance
      end
    end

    def count
      self[:count].to_i
    end

    def respond_to?(method_id, include_private = false)
      !!tag_types_for_questioner_method(method_id) || super
    end

    # Carried over from tagging.
    def has_tagger?
      !self[:tagger_id].nil?
    end

    private

    def tag_types_for_questioner_method(method_name)
      method_name[-1]=="?" && Type.cache[method_name[0..-2]]
    end

    def method_missing(method_name, *args, &block)
      if types = tag_types_for_questioner_method(method_name)
        self.class.send(:define_method, method_name) do
          types.any? { |type| is_a?(type.klass) }
        end
        send(method_name)
      else
        super
      end
    end

      # Ensure that the value follows the case-sensitivity from the possible_values.
    def ensure_possible_values
      if value = self.class.detect_possible_value(self.value)
        self.value = value
      end
      true
    end

    def validate_possible_values
      if possible_values && !possible_values.include?(value)
        errors.add(:value, %{Value "#{value}" not found in list: #{possible_values.inspect}})
      end
    end

    class Type < String

      # "tag" should always correspond with demodulize name of the base Tag class (ie Tagtical::Tag).
      BASE = "tag".freeze

      attr_reader :taggable_class

      def initialize(str, taggable_class, options={})
        options.each { |k, v| instance_variable_set("@#{k}", v) }
        @taggable_class = taggable_class
        super(str)
      end

      @@cache = {}
      cattr_reader :cache

      class << self
        def find(input, taggable_class)
          case input
          when self then input
          when String, Symbol then new(sanitize(input), taggable_class)
          when Hash  then input.map { |input, klass| new(sanitize(input), taggable_class, :klass => klass) }
          when Array then input.map { |c| find(c, taggable_class) }.flatten
          end
        end
        alias :[] :find

        # Stores the tag types in memory
        def register(inputs, taggable_class)
          find(inputs, taggable_class).each do |tag_type|
            cache[tag_type] ||= []
            cache[tag_type] << tag_type unless cache[tag_type].include?(tag_type)
          end
        end

        private

        # Sanitize the input for type name consistency and klass.
        def sanitize(input)
          input.to_s.singularize.underscore.gsub(/_tag$/, '')
        end
      end

      # Matches the string against the type after sanitizing it.
      def match?(input)
        self==self.class.send(:sanitize, input)
      end

      def comparable_array
        [to_s, klass]
      end

      def ==(input)
        case input
        when self.class then comparable_array==input.comparable_array
        when String then input==self
        else false
        end
      end

      # Leverages current type_condition logic from ActiveRecord while also allowing for type conditions
      # when no Tag subclass is defined. Also, it builds the type condition for STI inheritance.
      #
      # Options:
      #   <tt>sql</tt> - Set to true to return sql string. Set to :append to return a sql string which can be appended as a condition.
      #   <tt>only</tt> - An array of the following: :parents, :current, :children. Will construct conditions to query the current, parent, and/or children STI classes.
      #
      def finder_type_condition(*args)
        sql = args[-1].is_a?(Hash) && args[-1].delete(:sql)

        sti_column = Tagtical::Tag.arel_table[Tagtical::Tag.inheritance_column]
        sti_names = expand_tag_types(*args).map { |x| x.klass.sti_name }

        condition = sti_column.eq(sti_names.delete(nil)) if sti_names.include?(nil)
        sti_names_condition = sti_column.in(sti_names)
        condition = condition ? condition.or(sti_names_condition) : sti_names_condition
        
        if condition && sql
          condition = condition.to_sql
          condition.insert(0, " AND ") if sql==:append
        end
        
        condition
      end

      # Accepts:
      #   scoping(:<=)
      #   scoping(:scoping => :<=)
      def scoping(*args, &block)
        finder_type_condition = finder_type_condition(*args)
        if block_given?
          if finder_type_condition
            Tagtical::Tag.send(:with_scope, :find => Tagtical::Tag.where(finder_type_condition), :create => {:type => klass.sti_name}) do
              Tagtical::Tag.instance_exec(&block)
            end
          else
            Tagtical::Tag.instance_exec(&block)
          end
        else
          Tagtical::Tag.send(*(finder_type_condition ? [:where, finder_type_condition] : :unscoped))
        end
      end

      # Return the Tag subclass
      def klass
        @klass ||= find_tag_class!
      end

      def base?
        BASE==self
      end

      def has_many_name
        pluralize.to_sym
      end
      alias scope_name has_many_name

      def tag_list_name(prefix=nil)
        prefix = prefix.to_s.dup
        prefix << "_" unless prefix.blank?
        "#{prefix}#{self}_list"
      end

      def tag_list_ivar(*args)
        "@#{tag_list_name(*args)}"
      end

      def all_tag_list_ivar
        tag_list_ivar(:all)
      end

      def scope_ivar
        "@#{scope_name}"
      end

      # Returns the level from which it extends from Tagtical::Tag
      def active_record_sti_level
        @active_record_sti_level ||= begin
          count, current_class = 0, klass
          while !current_class.descends_from_active_record?
            current_class = current_class.superclass
            count += 1
          end
          count
        end
      end

      def expand_tag_types(*args)
        scopes, options = convert_finder_type_arguments(*args)
        classes, types = [], []

        types.concat(Array(options[:types]).map { |t| taggable_class.find_tag_type!(t) }) if options[:types]

        if scopes.include?(:current)
          classes << klass
        end
        if scopes.include?(:children)
          classes.concat(klass.descendants)
        end
        if scopes.include?(:parents) # include searches up the STI chain
          parent_class = klass.superclass
          while parent_class <= Tagtical::Tag
            classes << parent_class
            parent_class = parent_class.superclass
          end
        end

        if options[:only]
          classes &= find_tag_classes_for(options[:only])
        elsif options[:except]
          except = find_tag_classes_for(options[:except])
          classes.reject! { |t| except.any? { |e| t <= e }}
        end
        tag_types_by_classes = taggable_class.tag_types.index_by(&:klass)
        types.concat(classes.map { |k| tag_types_by_classes[k] }.uniq.compact)

        types # for clarity
      end

      private

      # Returns an array of potential class names for this specific type.
      def derive_class_candidates
        [].tap do |arr|
          suffixes = [classify]
          klass = taggable_class
          while klass < ActiveRecord::Base
            suffixes.concat ["#{klass}#{classify}", "#{klass}::#{classify}"]
            klass = klass.superclass
          end
          suffixes.map { |s| [s, "#{s}Tag"] }.flatten.each do |name| # support Interest and InterestTag class names.
            "Tagtical::Tag".tap do |longest_candidate|
              longest_candidate << "::#{name}" unless name=="Tag"
            end.scan(/^|::/) { arr << $' } # Klass, Tag::Klass, Tagtical::Tag::Klass
          end
        end.uniq.sort_by { |candidate| [candidate.split("::").size, candidate.length] }.reverse # more nested classnames first
      end

      # Take operator types (ie <, >, =) and convert them into :children, :current, or :parents.
      def convert_scope_options(input)
        Array.wrap(input || [:current, :children]).map do |type|
          if (t = type.to_s)=~/^[=><]+$/
            {"=" => :current, ">" => :parents, "<" => :children}.map do |operator, val|
              val if t.include?(operator)
            end.compact
          else
            type
          end
        end.flatten.uniq
      end

      def find_tag_class!
        return Tagtical::Tag if base?

        # Logic comes from ActiveRecord::Base#compute_type.
        derive_class_candidates.each do |candidate|
          begin
            constant = ActiveSupport::Dependencies.constantize(candidate)
            return constant if candidate == constant.to_s && constant <= Tagtical::Tag
          rescue NameError => e
            # We don't want to swallow NoMethodError < NameError errors
            raise e unless e.instance_of?(NameError)
          rescue ArgumentError
          end
        end

        raise("Cannot find tag class for type: #{self} with taggable class: #{taggable_class}")
      end

      def convert_finder_type_arguments(*args)
        options = args.extract_options!
        scopes = convert_scope_options(args.presence || options[:scope])
        scopes.delete(:parents) if klass && !klass.finder_needs_type_condition?  # we are at the topmost level.
        [scopes, options]
      end

      def find_tag_classes_for(input)
        Array(input).map { |o| taggable_class.find_tag_type!(o).klass }
      end

    end
  end
end
