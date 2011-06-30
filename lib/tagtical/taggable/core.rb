module Tagtical::Taggable
  module Core
    def self.included(base)
      base.class_eval do
        include Tagtical::Taggable::Core::InstanceMethods
        extend Tagtical::Taggable::Core::ClassMethods

        after_save :save_tags

        initialize_tagtical_core
      end
    end
    
    module ClassMethods
      def initialize_tagtical_core
        has_many :taggings, :as => :taggable, :dependent => :destroy, :include => :tag, :class_name => "Tagtical::Tagging"
        # has_many :tags, :through => :taggings, :source => :tag, :class_name => "Tagtical::Tag"

        tag_types.each do |tag_type|
          conditions = %{"#{Tagtical::Tag.table_name}"."id" = "#{Tagtical::Tagging.table_name}"."tag_id"}
          conditions << " AND #{tag_type.klass.send(:type_condition).to_sql}" if tag_type.klass.finder_needs_type_condition?

          has_many tag_type.pluralize.to_sym, :through => :taggings, :source => :tag,
            :class_name => "Tagtical::Tag", :conditions => conditions



          #  context_taggings = "#{tag_type}_taggings".to_sym
            # context_tags     = tag_type.to_sym
          #
          #  class_eval do
          #    has_many context_taggings, :as => :taggable, :dependent => :destroy, :include => :tag, :class_name => "Tagtical::Tagging",
          #    :conditions => ["#{Tagtical::Tagging.table_name}.tag_id = #{Tagtical::Tag.table_name}.id AND #{Tagtical::Tagging.table_name}.context = ?", tags_type]
            #  puts tag_type.scope_name

          #  end

          # In the case of the base tag type, it will just use the :tags association defined above.
          unless tag_type.base?
            Tagtical::Tag.scope(tag_type.scope_name, tag_type.klass.unscoped)  # looks confusing but checkout ActiveRecord::Base#unscoped
           # delegate tag_type.scope_name, :to => :tags
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{tag_type}_list
              tag_list_on('#{tag_type}')
            end

            def #{tag_type}_list=(new_tags)
              set_tag_list_on('#{tag_type}', new_tags)
            end

            def all_#{tag_type.pluralize}_list
              all_tags_list_on('#{tag_type}')
            end
          RUBY
          
        end        
      end
      
      def acts_as_taggable(*args)
        super(*args)
        initialize_tagtical_core
      end
      
      # all column names are necessary for PostgreSQL group clause
      def grouped_column_names_for(object)
        object.column_names.map { |column| "#{object.table_name}.#{column}" }.join(", ")
      end

      ##
      # Return a scope of objects that are tagged with the specified tags.
      #
      # @param tags The tags that we want to query for
      # @param [Hash] options A hash of options to alter you query:
      #                       * <tt>:exclude</tt> - if set to true, return objects that are *NOT* tagged with the specified tags
      #                       * <tt>:any</tt> - if set to true, return objects that are tagged with *ANY* of the specified tags
      #                       * <tt>:match_all</tt> - if set to true, return objects that are *ONLY* tagged with the specified tags
      #
      # Example:
      #   User.tagged_with("awesome", "cool")                     # Users that are tagged with awesome and cool
      #   User.tagged_with("awesome", "cool", :exclude => true)   # Users that are not tagged with awesome or cool
      #   User.tagged_with("awesome", "cool", :any => true)       # Users that are tagged with awesome or cool
      #   User.tagged_with("awesome", "cool", :match_all => true) # Users that are tagged with just awesome and cool
      def tagged_with(tags, options = {})
        tag_list = Tagtical::TagList.from(tags)

        return {} if tag_list.empty?

        joins = []
        conditions = []

        options[:on] ||= Tagtical::Tag::Type::BASE
        tag_type = Tagtical::Tag::Type.find!(options.delete(:on))

        if options.delete(:exclude)
          tags_conditions = tag_list.map { |t| sanitize_sql(["#{Tagtical::Tag.table_name}.value LIKE ?", t]) }.join(" OR ")
          conditions << "#{table_name}.#{primary_key} NOT IN (SELECT #{Tagtical::Tagging.table_name}.taggable_id FROM #{Tagtical::Tagging.table_name} JOIN #{Tagtical::Tag.table_name} ON #{Tagtical::Tagging.table_name}.tag_id = #{Tagtical::Tag.table_name}.id AND (#{tags_conditions}) WHERE #{Tagtical::Tagging.table_name}.taggable_type = #{quote_value(base_class.name)})"

        elsif options.delete(:any)
          conditions << tag_list.map { |t| sanitize_sql(["#{Tagtical::Tag.table_name}.value LIKE ?", t]) }.join(" OR ")

          tagging_join  = " JOIN #{Tagtical::Tagging.table_name}" +
                          "   ON #{Tagtical::Tagging.table_name}.taggable_id = #{table_name}.#{primary_key}" +
                          "  AND #{Tagtical::Tagging.table_name}.taggable_type = #{quote_value(base_class.name)}" +
                          " JOIN #{Tagtical::Tag.table_name}" +
                          "   ON #{Tagtical::Tagging.table_name}.tag_id = #{Tagtical::Tag.table_name}.id"

          if tag_type && tag_type.klass.finder_needs_type_condition?
             conditions << " AND #{tag_type.klass.send(:type_condition).to_sql}"
          end
          select_clause = "DISTINCT #{table_name}.*" unless !tag_type.base? and tag_types.one?

          joins << tagging_join

        else
          tags_by_value = tag_type.klass.where_any_like(tag_list).group_by(&:value)
          return scoped(:conditions => "1 = 0") unless tags_by_value.length == tag_list.length # allow for chaining

          # Create only one join per tag value.
          tags_by_value.each do |value, tags|
            tags.each do |tag|
              safe_tag = value.gsub(/[^a-zA-Z0-9]/, '')
              prefix   = "#{safe_tag}_#{rand(1024)}"

              taggings_alias = "#{undecorated_table_name}_taggings_#{prefix}"

              tagging_join  = "JOIN #{Tagtical::Tagging.table_name} #{taggings_alias}" +
                "  ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key}" +
                " AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}" +
                " AND #{sanitize_sql("#{taggings_alias}.tag_id" => tags.map(&:id))}"

              joins << tagging_join
            end
          end
        end

        taggings_alias, tags_alias = "#{undecorated_table_name}_taggings_group", "#{undecorated_table_name}_tags_group"

        if options.delete(:match_all)
          joins << "LEFT OUTER JOIN #{Tagtical::Tagging.table_name} #{taggings_alias}" +
                   "  ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key}" +
                   " AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}"


          group_columns = Tagtical::Tag.using_postgresql? ? grouped_column_names_for(self) : "#{table_name}.#{primary_key}"
          group = "#{group_columns} HAVING COUNT(#{taggings_alias}.taggable_id) = #{tag_list.size}"
        end

        scoped(:select     => select_clause,
               :joins      => joins.join(" "),
               :group      => group,
               :conditions => conditions.join(" AND "),
               :order      => options[:order],
               :readonly   => false)
      end

      def is_taggable?
        true
      end
    end    
    
    module InstanceMethods
      # all column names are necessary for PostgreSQL group clause
      def grouped_column_names_for(object)
        self.class.grouped_column_names_for(object)
      end

      def is_taggable?
        self.class.is_taggable?
      end

      def cached_tag_list_on(context)
        self[tag_type(context).tag_list_name(:cached)]
      end

      def tag_list_cache_set_on?(context)
        variable_name = tag_type(context).tag_list_ivar
        !instance_variable_get(variable_name).nil?
      end

      def tag_list_cache_on(context)
        variable_name = tag_type(context).tag_list_ivar
        instance_variable_get(variable_name) || instance_variable_set(variable_name, Tagtical::TagList.new(tags_on(context).map(&:value)))
      end

      def tag_list_on(context)
        tag_list_cache_on(context)
      end

      def all_tags_list_on(context)
        variable_name = tag_type(context).tag_list_ivar(:all)
        return instance_variable_get(variable_name) if instance_variable_get(variable_name)

        instance_variable_set(variable_name, Tagtical::TagList.new(all_tags_on(context).map(&:value)).freeze)
      end

      if Tagtical.config.support_multiple_taggers?
        ##
        # Returns all tags of a given context
        def all_tags_on(context)
          tag_table_name = Tagtical::Tag.table_name
          tagging_table_name = Tagtical::Tagging.table_name

          scope = tag_scope(context)

          if Tagtical::Tag.using_postgresql?
            group_columns = grouped_column_names_for(Tagtical::Tag)
            scope = scope.order("max(#{tagging_table_name}.created_at)").group(group_columns)
          else
            scope = scope.group("#{Tagtical::Tag.table_name}.#{Tagtical::Tag.primary_key}")
          end

          scope.all
        end

        ##
        # Returns all tags that aren't owned.
        def tags_on(context)
          tag_scope(context).where("#{ActsAsTaggableOn::Tagging.table_name}.tagger_id IS NULL").all
        end
      else
        # If we don't support multiple taggers, these behave the same.
        def all_tags_on(context)
          tag_scope(context).all
        end
        alias :tags_on :all_tags_on
      end

      def set_tag_list_on(context, new_list)
        variable_name = tag_type(context).tag_list_ivar
        instance_variable_set(variable_name, Tagtical::TagList.from(new_list))
      end

      def reload(*args)
        self.class.tag_types.each do |tag_type|
          instance_variable_set(tag_type.tag_list_ivar, nil)
          instance_variable_set(tag_type.tag_list_ivar(:all), nil)
        end
      
        super(*args)
      end

      def save_tags
        # Do the classes from top to bottom. We want the list from "tag" to run before "sub_tag" runs.
        # Otherwise, we will end up removing taggings from "sub_tag" since they aren't on "tag'.
        self.class.tag_types.sort_by(&:active_record_sti_level).each do |tag_type|
          next unless tag_list_cache_set_on?(tag_type)

          tag_list = tag_list_cache_on(tag_type).uniq

          # Find existing tags or create non-existing tags:
          tag_list = tag_type.klass.find_or_create_tag_list(tag_list)

          current_tags = tags_on(tag_type)
          old_tags     = current_tags - tag_list
          new_tags     = tag_list     - current_tags

          # Find taggings to remove:
          old_taggings = old_tags.empty? ? [] : taggings.find_all_by_tag_id(old_tags)

          if old_taggings.present?
            Tagtical::Tagging.destroy_all :id => old_taggings.map(&:id) # Destroy old taggings:
          end

          new_tags.each do |tag|
            taggings.create!(:tag_id => tag.id, :taggable => self) # Create new taggings:
          end
        end

        true
      end

      private

      def tag_scope(input)
        send(tag_type(input).scope_name)
      end

      # Returns the tag type for the given context and raises an error if it's not a valid tag type.
      def tag_type(input)
        (@tag_type ||= {})[input] ||= Tagtical::Tag::Type[input].tap do |tag_type|
          raise("Invalid tag type: #{tag_type}. Must be in #{self.class.tag_types}.") unless self.class.tag_types.include?(tag_type)
        end
      end

    end
  end
end
