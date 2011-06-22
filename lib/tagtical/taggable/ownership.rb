module Tagtical::Taggable
  module Ownership
    def self.included(base)
      base.send :include, Tagtical::Taggable::Ownership::InstanceMethods
      base.extend Tagtical::Taggable::Ownership::ClassMethods
     
      base.class_eval do
        after_save :save_owned_tags    
      end
      
      base.initialize_acts_as_taggable_ownership
    end
    
    module ClassMethods
      def acts_as_taggable(*args)
        initialize_acts_as_taggable_ownership
        super(*args)
      end
      
      def initialize_acts_as_taggable_ownership
        tag_types.map(&:to_s).each do |tag_type|
          class_eval %(
            def #{tag_type}_from(owner)
              owner_tag_list_on(owner, '#{tag_type}')
            end      
          )
        end        
      end
    end

    Tagtical.polymorphic_tagger

    module InstanceMethods
      def owner_tags_on(owner, context)
        conditions = [[%{#{Tagtical::Tagging.table_name}.context = ?}, context.to_s]]
        if owner
          conditions << [[%{#{Tagtical::Tagging.table_name}.tagger_id = ?}, owner.id]]
          conditions << [[%{#{Tagtical::Tagging.table_name}.tagger_type = ?}, owner.class.to_s]] if Tagtical.polymorphic_tagger
        end
        conditions = conditions.each_with_object([""]) do |(condition, value), arr|
          arr.first << condition
          arr << value
        end
        where(conditions).all
      end

      def cached_owned_tag_list_on(context)
        variable_name = "@owned_#{context}_list"
        cache = instance_variable_get(variable_name) || instance_variable_set(variable_name, {})
      end
      
      def owner_tag_list_on(owner, context)
        add_custom_context(context)

        cache = cached_owned_tag_list_on(context)
        cache.delete_if { |key, value| key.id == owner.id && key.class == owner.class }
        
        cache[owner] ||= Tagtical::TagList.new(*owner_tags_on(owner, context).map(&:value))
      end
      
      def set_owner_tag_list_on(owner, context, new_list)
        add_custom_context(context)
        
        cache = cached_owned_tag_list_on(context)
        cache.delete_if { |key, value| key.id == owner.id && key.class == owner.class }

        cache[owner] = Tagtical::TagList.from(new_list)
      end
      
      def reload(*args)
        self.class.tag_types.each do |context|
          instance_variable_set("@owned_#{context}_list", nil)
        end
      
        super(*args)
      end
    
      def save_owned_tags
        tagging_contexts.each do |context|
          cached_owned_tag_list_on(context).each do |owner, tag_list|
            # Find existing tags or create non-existing tags:
            tag_list = Tagtical::Tag.find_or_create_all_with_like_by_value(tag_list.uniq)

            owned_tags = owner_tags_on(owner, context)              
            old_tags   = owned_tags - tag_list
            new_tags   = tag_list   - owned_tags
          
            # Find all taggings that belong to the taggable (self), are owned by the owner, 
            # have the correct context, and are removed from the list.
            old_taggings = Tagtical::Tagging.where(:taggable_id => id, :taggable_type => self.class.base_class.to_s,
                                                           :tagger_type => owner.class.to_s, :tagger_id => owner.id,
                                                           :tag_id => old_tags, :context => context).all
          
            if old_taggings.present?
              # Destroy old taggings:
              Tagtical::Tagging.destroy_all(:id => old_taggings.map(&:id))
            end

            # Create new taggings:
            new_tags.each do |tag|
              taggings.create!(:tag_id => tag.id, :context => context.to_s, :tagger => owner, :taggable => self)
            end
          end
        end
        
        true
      end
    end
  end
end