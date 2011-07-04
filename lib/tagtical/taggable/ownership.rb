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
      def owner_tags_on(owner, context, options={})
        scope = tag_scope(context, options)
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
        tag_types.each do |tag_type|
          instance_variable_set(tag_type.tag_list_ivar(:owned), nil)
        end

        super(*args)
      end

      def save_owned_tags
        # Do the classes from top to bottom. We want the list from "tag" to run before "sub_tag" runs.
        # Otherwise, we will end up removing taggings from "sub_tag" since they aren't on "tag'.
        tag_types.sort_by(&:active_record_sti_level).each do |tag_type|
          cached_owned_tag_list_on(tag_type).each do |owner, tag_list|
            # Find existing tags or create non-existing tags:
            tag_value_lookup = tag_type.scoped(:find_or_create_tags, tag_list)
            tags = tag_value_lookup.keys

            owned_tags = owner_tags_on(owner, tag_type, :parents => true)
            old_tags   = owned_tags - tags
            new_tags   = tags       - owned_tags

            # Find and remove old taggings:
            if old_tags.present? && (old_taggings = owner_taggings.find_all_by_tag_id(old_tags)).present?
              old_taggings.reject! do |tagging|
                if tagging.tag.class > tag_type.klass! # parent of current tag type/class, make sure not to remove these taggings.
                  update_tagging_with_inherited_tag!(tagging, new_tags, tag_value_lookup)
                  true
                end
              end
              Tagtical::Tagging.destroy_all :id => old_taggings.map(&:id) # Destroy old taggings:
            end

            # Create new taggings:
            new_tags.each do |tag|
              attrs = {:tagger => owner, :relevance => tag_value_lookup[tag].relevance}
              if !Tagtical.config.support_multiple_taggers? && (current_tagging = taggings.find_by_tag_id(tag.id))
                current_tagging.update_attributes!(attrs) # overwrite the tagger if there is one.
              else
                taggings.create!(attrs.merge(:tag_id => tag.id))
              end
            end
          end
        end

        true
      end

      # Find all taggings that belong to the taggable (self), are owned by the owner,
      # have the correct context, and are removed from the list.
      def owner_taggings
        relation = taggings
        if Tagtical.config.support_multiple_taggers?
          relation = relation.where(:tagger_id   => owner.id)
          relation = relation.where(:tagger_type => owner.class.to_s) if Tagtical.config.polymorphic_tagger?
        end
        relation
      end

    end
  end
end