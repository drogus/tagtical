module Tagtical
  class Tag < ::ActiveRecord::Base

    attr_accessible :value

    ### ASSOCIATIONS:

    has_many :taggings, :dependent => :destroy, :class_name => 'Tagtical::Tagging'

    ### VALIDATIONS:

    validates_presence_of :value # type is not required, it can be blank
    validates_uniqueness_of :value, :scope => :type

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
      def find_or_create_tag_list(*list)
        list = [list].flatten

        return [] if list.empty?

        existing_tags = where_any_like(list).all
        new_tag_values = list.reject do |value|
          value = comparable_value(value)
          existing_tags.any? { |tag| comparable_value(tag.value) == value }
        end
        created_tags  = new_tag_values.map { |value| create!(:value => value) }

        existing_tags + created_tags
      end

      def sti_name
        @sti_name ||= Type.new(name.demodulize)
      end

      protected

      def compute_type(type_name)
        @@compute_type ||= {}
        # super is required when it gets called from a reflection.
        @@compute_type[type_name] || super
      rescue Exception => e
        @@compute_type[type_name] = Type.new(type_name).klass
      end

      private

      def comparable_value(str)
        RUBY_VERSION >= "1.9" ? str.downcase : str.mb_chars.downcase
      end

    end

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(self.class) && value == object.value)
    end

    # Try to sort by the relevance if provided.
    def <=>(tag)
      if (r1 = self["relevance"]) && (r2 = tag["relevance"])
        r1.to_f <=> r2.to_f
      else
        value <=> tag.value
      end
    end

    def to_s
      value
    end

    # We return nil if we are *not* an STI class.
    def type
      type = read_attribute(:type)
      type && Type[type]
    end

    def count
      read_attribute(:count).to_i
    end

    class Type < String

      # "tag" should always correspond with demodulize name of the base Tag class (ie Tagtical::Tag).
      BASE = "tag".freeze

      # Default to simply "tag", if none is provided. This will return Tagtical::Tag on calls to #klass
      def initialize(arg)
        super(arg.to_s.singularize.underscore.gsub(/_tag$/, ''))
      end

      class << self
        def find(input)
          return input.map { |c| self[c] } if input.is_a?(Array)
          input.is_a?(self) ? input : new(input)
        end
        alias :[] :find

        # Raises an error if the type is not valid.
        def find!(input)
          find(input).tap { |type| type.validate! if type }
        end
      end

      def validate!
        raise("Cannot find subclass of Tagtical::Tag for #{self}") if klass.nil?
      end

      # Return the Tag subclass
      def klass
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

      alias :scope_name :pluralize

      def base?
        klass.descends_from_active_record?
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
          count, current_class = 0, klass
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

    end

  end
end
