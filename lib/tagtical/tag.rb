module Tagtical
  class Tag < ::ActiveRecord::Base

    class_attribute :default_relevance, :instance_writer => false
    self.default_relevance = 1

    attr_accessible :value, :relevance

    ### ASSOCIATIONS:

    has_many :taggings, :dependent => :destroy, :class_name => 'Tagtical::Tagging'

    ### VALIDATIONS:

    validates_presence_of :value, :type
    validates_uniqueness_of :value, :scope => :type

    before_create { |record| record.relevance ||= default_relevance }

    self.store_full_sti_class = false

    ### CLASS METHODS:

    class << self

      def where_any(list, wildcard=false)
        char = "%" if wildcard
        operator = wildcard ? (connection.adapter_name=='PostgreSQL' ? 'ILIKE' : 'LIKE') : "="
        conditions = Array(list).map { |tag| ["value #{operator} ?", "#{char}#{tag.to_s}#{char}"] }
        where(conditions.size==1 ? conditions.first : conditions.map { |c| sanitize_sql(c) }.join(" OR "))
      end

      def where_any_like(list)
        where_any(list, true)
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
          existing_tags.any? { |tag|  comparable_value(tag.value) == value }
        end
        created_tags  = new_tag_values.map { |value| Tag.create(:value => value) }

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

    def <=>(tag)
      relevance <=> tag.relevance
    end

    def to_s
      value
    end

    def type
      Type[read_attribute(:type) || "tag"]
    end

    def count
      read_attribute(:count).to_i
    end

    class Type < String

      def initialize(arg)
        super(arg.to_s.singularize.underscore.gsub(/_tag$/, ''))
      end

      def self.[](input)
        return input.map { |c| self[c] } if input.is_a?(Array)
        input.is_a?(self) ? input : new(input)
      end

      # Return the Tag subclass
      def klass
        longest_candidate = "Tagtical::Tag#{"::#{class_name}" unless class_name=="Tag"}"
        candidates = [].tap { |arr| longest_candidate.scan(/^|::/) { arr << $' } }.reverse # Klass, Tag::Klass, Tagtical::Tag::Klass

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
      end

      alias :class_name :classify
      alias :scope_name :to_s

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

    end

  end
end
