module Tagtical::Taggable
  module Core
    def self.included(base)
      base.send :include, Tagtical::Taggable::Core::InstanceMethods
      base.extend Tagtical::Taggable::Core::ClassMethods

      base.class_eval do
        attr_writer :custom_contexts
        after_save :save_tags
      end
      
      base.initialize_tagtical_core
    end
    
    module ClassMethods
      def initialize_tagtical_core
        tag_types.map(&:to_s).each do |tags_type|
          tag_type         = tags_type.to_s.singularize
          context_taggings = "#{tag_type}_taggings".to_sym
          context_tags     = tags_type.to_sym

          class_eval do
            has_many context_taggings, :as => :taggable, :dependent => :destroy, :include => :tag, :class_name => "Tagtical::Tagging",
            :conditions => ["#{Tagtical::Tagging.table_name}.tag_id = #{Tagtical::Tag.table_name}.id AND #{Tagtical::Tagging.table_name}.context = ?", tags_type]
            has_many context_tags, :through => context_taggings, :source => :tag, :class_name => "Tagtical::Tag"
          end

          class_eval %(
            def #{tag_type}_list
              tag_list_on('#{tags_type}')
            end

            def #{tag_type}_list=(new_tags)
              set_tag_list_on('#{tags_type}', new_tags)
            end

            def all_#{tags_type}_list
              all_tags_list_on('#{tags_type}')
            end
          )
        end        
      end
      
      def tagtical(*args)
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

        context = options.delete(:on)

        if options.delete(:exclude)
          tags_conditions = tag_list.map { |t| sanitize_sql(["#{Tagtical::Tag.table_name}.name LIKE ?", t]) }.join(" OR ")
          conditions << "#{table_name}.#{primary_key} NOT IN (SELECT #{Tagtical::Tagging.table_name}.taggable_id FROM #{Tagtical::Tagging.table_name} JOIN #{Tagtical::Tag.table_name} ON #{Tagtical::Tagging.table_name}.tag_id = #{Tagtical::Tag.table_name}.id AND (#{tags_conditions}) WHERE #{Tagtical::Tagging.table_name}.taggable_type = #{quote_value(base_class.name)})"

        elsif options.delete(:any)
          conditions << tag_list.map { |t| sanitize_sql(["#{Tagtical::Tag.table_name}.name LIKE ?", t]) }.join(" OR ")

          tagging_join  = " JOIN #{Tagtical::Tagging.table_name}" +
                          "   ON #{Tagtical::Tagging.table_name}.taggable_id = #{table_name}.#{primary_key}" +
                          "  AND #{Tagtical::Tagging.table_name}.taggable_type = #{quote_value(base_class.name)}" +
                          " JOIN #{Tagtical::Tag.table_name}" +
                          "   ON #{Tagtical::Tagging.table_name}.tag_id = #{Tagtical::Tag.table_name}.id"

          tagging_join << "  AND " + sanitize_sql(["#{Tagtical::Tagging.table_name}.context = ?", context.to_s]) if context
          select_clause = "DISTINCT #{table_name}.*" unless context and tag_types.one?

          joins << tagging_join

        else
          tags = Tagtical::Tag.named_any(tag_list)
          return scoped(:conditions => "1 = 0") unless tags.length == tag_list.length

          tags.each do |tag|
            safe_tag = tag.value.gsub(/[^a-zA-Z0-9]/, '')
            prefix   = "#{safe_tag}_#{rand(1024)}"

            taggings_alias = "#{undecorated_table_name}_taggings_#{prefix}"

            tagging_join  = "JOIN #{Tagtical::Tagging.table_name} #{taggings_alias}" +
                            "  ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key}" +
                            " AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}" +
                            " AND #{taggings_alias}.tag_id = #{tag.id}"
            tagging_join << " AND " + sanitize_sql(["#{taggings_alias}.context = ?", context.to_s]) if context

            joins << tagging_join
          end
        end

        taggings_alias, tags_alias = "#{undecorated_table_name}_taggings_group", "#{undecorated_table_name}_tags_group"

        if options.delete(:match_all)
          joins << "LEFT OUTER JOIN #{Tagtical::Tagging.table_name} #{taggings_alias}" +
                   "  ON #{taggings_alias}.taggable_id = #{table_name}.#{primary_key}" +
                   " AND #{taggings_alias}.taggable_type = #{quote_value(base_class.name)}"


          group_columns = Tagtical::Tag.using_postgresql? ? grouped_column_names_for(self) : "#{table_name}.#{primary_key}"
          group = "#{group_columns} HAVING COUNT(#{taggings_alias}.taggable_id) = #{tags.size}"
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

      def custom_contexts
        @custom_contexts ||= []
      end

      def is_taggable?
        self.class.is_taggable?
      end

      def add_custom_context(value)
        custom_contexts << value.to_s unless custom_contexts.include?(value.to_s) or self.class.tag_types.map(&:to_s).include?(value.to_s)
      end

      def cached_tag_list_on(context)
        self["cached_#{context.to_s.singularize}_list"]
      end

      def tag_list_cache_set_on(context)
        variable_name = "@#{context.to_s.singularize}_list"
        !instance_variable_get(variable_name).nil?
      end

      def tag_list_cache_on(context)
        variable_name = "@#{context.to_s.singularize}_list"
        instance_variable_get(variable_name) || instance_variable_set(variable_name, Tagtical::TagList.new(tags_on(context).map(&:name)))
      end

      def tag_list_on(context)
        add_custom_context(context)
        tag_list_cache_on(context)
      end

      def all_tags_list_on(context)
        variable_name = "@all_#{context.to_s.singularize}_list"
        return instance_variable_get(variable_name) if instance_variable_get(variable_name)

        instance_variable_set(variable_name, Tagtical::TagList.new(all_tags_on(context).map(&:name)).freeze)
      end

      ##
      # Returns all tags of a given context
      def all_tags_on(context)
        tag_table_name = Tagtical::Tag.table_name
        tagging_table_name = Tagtical::Tagging.table_name

        opts  =  ["#{tagging_table_name}.context = ?", context.to_s]
        scope = tags.where(opts)
        
        if Tagtical::Tag.using_postgresql?
          group_columns = grouped_column_names_for(Tagtical::Tag)
          scope = scope.order("max(#{tagging_table_name}.created_at)").group(group_columns)
        else
          scope = scope.group("#{Tagtical::Tag.table_name}.#{Tagtical::Tag.primary_key}")
        end

        scope.all
      end

      ##
      # Returns all tags that are not owned of a given context
      def tags_on(context)
        tags.where(["#{Tagtical::Tagging.table_name}.context = ? AND #{Tagtical::Tagging.table_name}.tagger_id IS NULL", context.to_s]).all
      end

      def set_tag_list_on(context, new_list)
        add_custom_context(context)

        variable_name = "@#{context.to_s.singularize}_list"
        instance_variable_set(variable_name, Tagtical::TagList.from(new_list))
      end

      def tagging_contexts
        custom_contexts + self.class.tag_types.map(&:to_s)
      end

      def reload(*args)
        self.class.tag_types.each do |context|
          instance_variable_set("@#{context.to_s.singularize}_list", nil)
          instance_variable_set("@all_#{context.to_s.singularize}_list", nil)
        end
      
        super(*args)
      end

      def save_tags
        tagging_contexts.each do |context|
          next unless tag_list_cache_set_on(context)

          tag_list = tag_list_cache_on(context).uniq

          # Find existing tags or create non-existing tags:
          tag_list = Tagtical::Tag.find_or_create_all_with_like_by_value(tag_list)

          current_tags = tags_on(context)
          old_tags     = current_tags - tag_list
          new_tags     = tag_list     - current_tags
          
          # Find taggings to remove:
          old_taggings = taggings.where(:tagger_type => nil, :tagger_id => nil,
                                        :context => context.to_s, :tag_id => old_tags).all

          if old_taggings.present?
            # Destroy old taggings:
            Tagtical::Tagging.destroy_all :id => old_taggings.map(&:id)
          end

          # Create new taggings:
          new_tags.each do |tag|
            taggings.create!(:tag_id => tag.id, :context => context.to_s, :taggable => self)
          end
        end

        true
      end
    end
  end
end
