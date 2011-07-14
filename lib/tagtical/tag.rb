module Tagtical
  class Tag < ::ActiveRecord::Base
    
    attr_accessible :value

    has_many :taggings, :dependent => :destroy, :class_name => 'Tagtical::Tagging'

    scope(:type, lambda do |context, *args|
      options = args.extract_options!
      options[:type] = args[0] if args[0]
      Type[context].scoping(options)
    end)

    validates :value, :uniqueness => {:scope => :type}, :presence => true # type is not required, it can be blank

    class_attribute :possible_values
    validate :validate_possible_values
    
    self.store_full_sti_class = false

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

        existing_tags  = where_any_like(tag_list).all
        tag_list.each_with_object({}) do |value, tag_lookup|
          tag_lookup[detect_comparable(existing_tags, value) || create!(:value => value)] = value
        end
      end

      def sti_name
        return @sti_name if instance_variable_defined?(:@sti_name)
        @sti_name = Tagtical::Tag==self ? nil : Type[name.demodulize].to_sti_name
      end

      def define_scope_for_type(tag_type)
        scope(tag_type.scope_name, lambda { |*args| type(tag_type, *args) }) unless respond_to?(tag_type.scope_name)
      end

      protected

      def compute_type(type_name)
        @@compute_type ||= {}
        # super is required when it gets called from a reflection.
        @@compute_type[type_name] || super
      rescue Exception => e
        @@compute_type[type_name] = Type.new(type_name).klass!
      end

      private
      
      # Checks to see if a tags value is present in a set of tags and returns that tag.
      def detect_comparable(tags, value)
        value = comparable_value(value)
        tags.detect { |tag| comparable_value(tag.value) == value }
      end

      def comparable_value(str)
        RUBY_VERSION >= "1.9" ? str.downcase : str.mb_chars.downcase
      end

    end

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(self.class) && value == object.value)
    end

    def relevance
      (v = self[:relevance]) && v.to_f
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

    # We return nil if we are *not* an STI class.
    def type
      (type = self[:type]) && Type.new(type)
    end

    def count
      self[:count].to_i
    end

    private

    def method_missing(method_name, *args, &block)
      if method_name[-1]=="?"
        lambda = (klass = Type.new(method_name[0..-2]).klass) ?
          lambda { is_a?(klass) } :
          lambda { method_name[0..-2]==type }
        self.class.send(:define_method, method_name, &lambda)
        send(method_name)
      else
        super
      end
    end

    def validate_possible_values
      if possible_values && !possible_values.include?(value)
        errors.add(:value, %{Value "#{value}" not found in list: #{possible_values.inspect}})
      end
    end

    class Type < String

      # "tag" should always correspond with demodulize name of the base Tag class (ie Tagtical::Tag).
      BASE = "tag".freeze

      class << self
        def find(input)
          return input.map { |c| self[c] } if input.is_a?(Array)
          input.is_a?(self) ? input : new(sanitize(input))
        end
        alias :[] :find

        private

        # Sanitize the input for type name consistency.
        def sanitize(input)
          input.to_s.singularize.underscore.gsub(/_tag$/, '')
        end
      end

      # The STI name for the Tag model is the same as the tag type.
      def to_sti_name
        self
      end

      # Leverages current type_condition logic from ActiveRecord while also allowing for type conditions
      # when no Tag subclass is defined. Also, it builds the type condition for STI inheritance.
      #
      # Options:
      #   <tt>sql</tt> - Set to true to return sql string. Set to :append to return a sql string which can be appended as a condition.
      #   <tt>only</tt> - An array of the following: :parents, :current, :children. Will construct conditions to query the current, parent, and/or children STI classes.
      #
      def finder_type_condition(options={})
        type = convert_type_options(options[:type])

        # If we want [:current, :children] or [:current, :children, :parents] and we don't need the finder type condition,
        # then that means we don't need a condition at all since we are at the top-level sti class and we are essentially
        # searching the whole range of sti classes.
        if klass && !klass.finder_needs_type_condition?
          type.delete(:parents) # we are at the topmost level.
          type = [] if type==[:current, :children] # no condition is required if we want the current AND the children.
        end

        sti_names = []
        if type.include?(:current)
          sti_names << (klass ? klass.sti_name : to_sti_name)
        end
        if type.include?(:children) && klass
          sti_names.concat(klass.descendants.map(&:sti_name))
        end
        if type.include?(:parents) && klass # include searches up the STI chain
          parent_class = klass.superclass
          while parent_class <= Tagtical::Tag
            sti_names << parent_class.sti_name
            parent_class = parent_class.superclass
          end
        end

        sti_column = Tagtical::Tag.arel_table[Tagtical::Tag.inheritance_column]
        condition = sti_names.inject(nil) do |conds, sti_name|
          cond = sti_column.eq(sti_name)
          conds.nil? ? cond : conds.or(cond)
        end
        
        if condition && options[:sql]
          condition = condition.to_sql
          condition.insert(0, " AND ") if options[:sql]==:append
        end
        condition
      end

      def scoping(options={}, &block)
        finder_type_condition = finder_type_condition(options)
        if block_given?
          if finder_type_condition
            Tagtical::Tag.send(:with_scope, :find => Tagtical::Tag.where(finder_type_condition), :create => {:type => self}) do
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
        instance_variable_get(:@klass) || instance_variable_set(:@klass, find_tag_class)
      end

      # Return the Tag class or return top-level
      def klass!
        klass || Tagtical::Tag
      end

      def has_many_name
        pluralize.to_sym
      end
      alias scope_name has_many_name

      def base?
        !!klass && klass.descends_from_active_record?
      end

      def ==(val)
        super(self.class[val])
      end

      def tag_list_name(prefix=nil)
        prefix = prefix.to_s.dup
        prefix << "_" unless prefix.blank?
        "#{prefix}#{self}_list"
      end

      def tag_list_ivar(*args)
        "@#{tag_list_name(*args)}"
      end

      # Returns the level from which it extends from Tagtical::Tag
      def active_record_sti_level
        @active_record_sti_level ||= begin
          count, current_class = 0, klass!
          while !current_class.descends_from_active_record?
            current_class = current_class.superclass
            count += 1
          end
          count
        end
      end

      private

      # Returns an array of potential class names for this specific type.
      def derive_class_candidates
        [].tap do |arr|
          [classify, "#{classify}Tag"].each do |name| # support Interest and InterestTag class names.
            "Tagtical::Tag".tap do |longest_candidate|
              longest_candidate << "::#{name}" unless name=="Tag"
            end.scan(/^|::/) { arr << $' } # Klass, Tag::Klass, Tagtical::Tag::Klass
          end
        end
      end

      # Take operator types (ie <, >, =) and convert them into :children, :current, or :parents.
      def convert_type_options(input)
        Array.wrap(input || (klass ? [:current, :children] : :current)).map do |type, i|
          if (t = type.to_s)=~/^[=><]+$/
            {"=" => :current, ">" => :parents, "<" => :children}.map do |operator, val|
              val if t.include?(operator)
            end.compact
          else
            type
          end
        end.flatten.uniq
      end

      def find_tag_class
        candidates = derive_class_candidates

        # Attempt to find the preloaded class instead of having to do NameError catching below.
        candidates.each do |candidate|
          constants = ActiveSupport::Dependencies::Reference.send(:class_variable_get, :@@constants)
          if constants.key?(candidate) && (constant = constants[candidate]) <= Tagtical::Tag # must check for key first, do not want to trigger default proc.
            return constant
          end
        end
        
        # Logic comes from ActiveRecord::Base#compute_type.
        candidates.each do |candidate|
          begin
            constant = ActiveSupport::Dependencies.constantize(candidate)
            return constant if candidate == constant.to_s && constant <= Tagtical::Tag
          rescue NameError => e
            # We don't want to swallow NoMethodError < NameError errors
            raise e unless e.instance_of?(NameError)
          rescue ArgumentError
          end
        end

        nil
      end
    end

  end
end
