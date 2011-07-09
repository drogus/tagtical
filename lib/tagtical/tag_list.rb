module Tagtical
  class TagList < Array
    class TagValue < String
      attr_accessor :relevance
      def initialize(value, relevance=nil)
        @relevance = relevance
        super(value.to_s)
      end
    end
    
    cattr_accessor :delimiter
    self.delimiter = ','

    attr_accessor :owner

    def initialize(*args)
      add(*args)
    end
  
    ##
    # Returns a new TagList using the given tag string.
    #
    # Example:
    #   tag_list = TagList.from("One , Two,  Three")
    #   tag_list # ["One", "Two", "Three"]
    def self.from(string)
      if string.is_a?(Hash)
        new(string)
      else
        glue   = delimiter.ends_with?(" ") ? delimiter : "#{delimiter} "
        string = string.join(glue) if string.respond_to?(:join)

        new.tap do |tag_list|
          string = string.to_s.dup

          # Parse the quoted tags
          string.gsub!(/(\A|#{delimiter})\s*"(.*?)"\s*(#{delimiter}\s*|\z)/) { tag_list << $2; $3 }
          string.gsub!(/(\A|#{delimiter})\s*'(.*?)'\s*(#{delimiter}\s*|\z)/) { tag_list << $2; $3 }

          tag_list.add(string.split(delimiter))
        end
      end
    end

    def concat(values)
      super(values.map! { |v| convert_tag_value(v) })
    end

    def push(value)
      super(convert_tag_value(value))
    end
    alias << push

    ##
    # Add tags to the tag_list. Duplicate or blank tags will be ignored.
    # Use the <tt>:parse</tt> option to add an unparsed tag string.
    #
    # Example:
    #   tag_list.add("Fun", "Happy")
    #   tag_list.add("Fun, Happy", :parse => true)
    #   tag_list.add("Fun" => "0.546", "Happy" => 0.465) # add relevance
    def add(*values)
      extract_and_apply_options!(values)
      concat(values)
      clean!
      self
    end

    ##
    # Remove specific tags from the tag_list.
    # Use the <tt>:parse</tt> option to add an unparsed tag string.
    #
    # Example:
    #   tag_list.remove("Sad", "Lonely")
    #   tag_list.remove("Sad, Lonely", :parse => true)
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
    #   tag_list = TagList.new("Round", "Square,Cube")
    #   tag_list.to_s # 'Round, "Square,Cube"'
    def to_s
      tags = frozen? ? self.dup : self
      tags.send(:clean!)

      tags.map do |value|
        value.include?(delimiter) ? "\"#{value}\"" : value
      end.join(delimiter.ends_with?(" ") ? delimiter : "#{delimiter} ")
    end

    # Builds an option statement for an ActiveRecord table.
    def to_sql_conditions(options={})
      options.reverse_merge!(:class => Tagtical::Tag, :column => "value", :operator => "=")
      "(" + map { |t| options[:class].send(:sanitize_sql, ["#{options[:class].table_name}.#{options[:column]} #{options[:operator]} ?", t]) }.join(" OR ") + ")"
    end

    private
  
    # Remove whitespace, duplicates, and blanks.
    def clean!
      reject!(&:blank?)
      each(&:strip!)
      uniq!(&:downcase)
    end

    def extract_and_apply_options!(args)
      if args.size==1 && args[0].is_a?(Hash)
        args.replace(args[0].map { |value, relevance| TagValue.new(value, relevance) })
      else
        options = args.last.is_a?(Hash) ? args.pop : {}
        options.assert_valid_keys :parse

        if options[:parse]
          args.map! { |a| self.class.from(a) }
        end

        args.flatten!
      end
    end

    def convert_tag_value(value)
      value.is_a?(TagValue) ? value : TagValue.new(value)
    end

  end
end