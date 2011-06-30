module Tagtical::Taggable
  module Ownership
    def self.included(base)
      base.send :include, Tagtical::Taggable::Ownership::InstanceMethods
      base.extend Tagtical::Taggable::Ownership::ClassMethods
     
      base.after_save :save_owned_tags 
      
      base.initialize_acts_as_taggable_ownership
    end
    
    module ClassMethods
      def acts_as_taggable(*args)
        initialize_acts_as_taggable_ownership
        super(*args)
      end
      
      def initialize_acts_as_taggable_ownership
        tag_types.each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{tag_type}_from(owner)
              owner_tag_list_on(owner, '#{tag_type}')
            end      
          RUBY
        end        
      end
    end

    module InstanceMethods
      def owner_tags_on(owner, context)
        scope = send(tag_type(context).scope_name)
        if owner
          scope = scope.where([%{#{Tagtical::Tagging.table_name}.tagger_id = ?}, owner.id])
          scope = scope.where([%{#{Tagtical::Tagging.table_name}.tagger_type = ?}, owner.class.to_s]) if Tagtical.config.polymorphic_tagger?
        end
        scope.all
      end

      def cached_owned_tag_list_on(context)
        variable_name = tag_type(context).tag_list_ivar(:owned)
        cache = instance_variable_get(variable_name) || instance_variable_set(variable_name, {})
      end
      
      def owner_tag_list_on(owner, context)
        cache = cached_owned_tag_list_on(context)
        cache.delete_if { |key, value| key.id == owner.id && key.class == owner.class }
        
        cache[owner] ||= Tagtical::TagList.new(*owner_tags_on(owner, context).map(&:value))
      end
      
      def set_owner_tag_list_on(owner, context, new_list)
        cache = cached_owned_tag_list_on(context)
        cache.delete_if { |key, value| key.id == owner.id && key.class == owner.class }

        cache[owner] = Tagtical::TagList.from(new_list)
      end
      
      def reload(*args)
        self.class.tag_types.each do |tag_type|
          instance_variable_set(tag_type.tag_list_ivar(:owned), nil)
        end
      
        super(*args)
      end
    
      def save_owned_tags
        tag_types.each do |tag_type|
          cached_owned_tag_list_on(tag_type).each do |owner, tag_list|
            # Find existing tags or create non-existing tags:
            tag_list = tag_type.klass.find_or_create_tag_list(tag_list.uniq)

            owned_tags = owner_tags_on(owner, tag_type)
            old_tags   = owned_tags - tag_list
            new_tags   = tag_list   - owned_tags
 
          
            # Find all taggings that belong to the taggable (self), are owned by the owner, 
            # have the correct context, and are removed from the list.
            conditions = {:taggable_id => id, :taggable_type => self.class.base_class.to_s, :tag_id => old_tags}
            if Tagtical.config.support_multiple_taggers?
              conditions.update(:tagger_id => owner.id)
              conditions.update(:tagger_type => owner.class.to_s) if Tagtical.config.polymorphic_tagger?
            end
            old_taggings = Tagtical::Tagging.where(conditions).all

            if old_taggings.present?
             # puts old_taggings.map(&:id).inspect
              # Destroy old taggings:
              Tagtical::Tagging.destroy_all(:id => old_taggings.map(&:id))
            end

            # Create new taggings:
            new_tags.each do |tag|
              if !Tagtical.config.support_multiple_taggers? && (current_tag = taggings.find_by_tag_id(tag.id))
                current_tag.update_attributes!(:tagger => owner) # overwrite the tagger if there is one.
              else
                taggings.create!(:tag_id => tag.id, :tagger => owner)
              end
            end
          end
        end
        
        true
      end
    end
  end
end