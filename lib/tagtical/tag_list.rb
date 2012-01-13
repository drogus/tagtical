module Tagtical
  class TagList < Array
    class TagValue < String

      attr_accessor :relevance

      cattr_accessor :relevance_delimiter
      self.relevance_delimiter = ':'

      def initialize(value="", relevance=nil)
        @relevance = relevance.to_f if relevance
        super(value)
      end

      def self.parse(input)
        new(*input.to_s.split(relevance_delimiter, 2).each(&:strip!))
      end
      
    end

    cattr_accessor :delimiter
    self.delimiter = ','

    cattr_accessor :value_quotes
    self.value_quotes = ["'", "\""]

    attr_accessor :owner

    def initialize(*args)
      add(*args) unless args.empty?
    end

    ##
    # Returns a new TagList using the given tag string.
    #
    # Example:
    #   tag_list = TagList.from("One , Two,  Three")
    #   tag_list # ["One", "Two", "Three"] <=== as TagValue
    def self.from(*args)
      args[0].is_a?(self) ? args[0] : new(*args)
    end

    def concat(values)
      super(values.map! { |v| convert_tag_value(v) })
    end

    def push(value)
      super(convert_tag_value(value))
    end
    alias << push

    # Shorthand
    def find(value)
      detect { |t| t==value }
    end

    ##
    # Add tags to the tag_list. Duplicate or blank tags will be ignored.
    # Use the <tt>:parse</tt> option to add an unparsed tag string.
    #
    # Example:
    #   tag_list.add("Fun", "Happy")
    #   tag_list.add("Fun, Happy")
    #   tag_list.add("Fun" => "0.546", "Happy" => 0.465) # add relevance
    def add(*values)
      extract_and_apply_options!(values)
      clean!(values) do
        concat(values)
      end
      self
    end

    ##
    # Remove specific tags from the tag_list.
    # Use the <tt>:parse</tt> option to add an unparsed tag string.
    #
    # Example:
    #   tag_list.remove("Sad", "Lonely")
    #   tag_list.remove("Sad, Lonely")
    def remove(*values)
      extract_and_apply_options!(values)
      delete_if { |value| values.include?(value) }
      self
    end

    ##
    # Transform the tag_list into a tag string suitable for edting in a form.
    # The tags are joined with <tt>TagList.delimiter</tt> and quoted if necessary.
    #
    # Example:
    #   tag_list = TagList.new("Round: 1.3", "Square,Cube")
    #   tag_list.to_s             # 'Round, "Square,Cube"'
    #   tag_list.to_s(:relevance) # 'Round:1.3, "Square,Cube"'
    def to_s(mode=nil)
      tag_list = frozen? ? self.dup : self
      tag_list.send(:clean!)
      tag_list.map do |tag_value|
        value = tag_value.include?(delimiter) ? %{"#{tag_value}"} : tag_value
        [value, (tag_value.relevance if mode==:relevance)].compact.join(TagValue.relevance_delimiter)
      end.join(delimiter.gsub(/(\S)$/, '\1 '))
    end

    # Builds an option statement for an ActiveRecord table.
    def to_sql_conditions(options={})
      options.reverse_merge!(:class => Tagtical::Tag, :column => "value", :operator => "=")
      "(" + map { |t| options[:class].send(:sanitize_sql, ["#{options[:class].table_name}.#{options[:column]} #{options[:operator]} ?", t]) }.join(" OR ") + ")"
    end

    private

    # Remove whitespace, duplicates, and blanks.
    def clean!(values=nil)
      delete_if { |value| values.include?(value) } if values.present? # Allow editing of relevance
      yield if block_given?
      reject!(&:blank?)
      each(&:strip!)
      uniq!(&:downcase)
    end

    def extract_and_apply_options!(args)
      options = args.last.is_a?(Hash) && args.size > 1 ? args.pop : {}
      options.assert_valid_keys :parse
      
      args.map! { |a| extract(a, options) }
      args.flatten!
    end

    # Returns an array by parsing the input.
    def extract(input, options={})
      case input
      when Tagtical::Tag
        TagValue.new(input.value, input.relevance)
      when String
        [].tap do |arr|
          if !input.include?(delimiter) || options[:parse]==false
            arr << input
          else
            input = input.dup

            # Parse the quoted tags
            value_quotes.each do |value_quote|
              input.gsub!(/(\A|#{delimiter})\s*#{value_quote}(.*?)#{value_quote}\s*(#{delimiter}\s*|\z)/) { arr << $2 ; $3 }
            end

            # Parse the unquoted tags
            input.split(delimiter).each { |word| arr << word.strip }
          end
        end
      when Hash
        input.map { |value, relevance| TagValue.new(value, relevance) }
      when Array
        input.map { |value| extract(value) }
      when Symbol # put at the end, rare case
        extract(input.to_s)
      when nil
        []
      else
        raise("Cannot parse: #{input.inspect}")
      end
    end

    def convert_tag_value(value)
      value.is_a?(TagValue) ? value : TagValue.parse(value)
    end

  end
end
