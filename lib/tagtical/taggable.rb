module Tagtical
  module Taggable
    def taggable?
      false
    end

    ##
    # Make a model taggable on specified contexts.
    #
    # @param [Array] tag_types An array of taggable contexts. These must have an associated subclass under Tag.
    #
    # Example:
    #   module Tag
    #     class Language < Tagtical::Tag
    #     end
    #     class Skill < Tagtical::Tag
    #     end
    #   end
    #   class User < ActiveRecord::Base
    #     acts_as_taggable :languages, :skills
    #   end
    def acts_as_taggable(*tag_types)
      tag_types.flatten!
      tag_types << Tagtical::Tag::Type::BASE # always include the base type.
      tag_types = Tagtical::Tag::Type.register(tag_types.uniq.compact, self)

      if taggable?
        self.tag_types = (self.tag_types + tag_types).uniq
      else
        class_attribute(:tag_types)
        self.tag_types = tag_types

        has_many :taggings, :as => :taggable, :dependent => :destroy, :include => :tag, :class_name => "Tagtical::Tagging"
        has_many :tags, :through => :taggings, :class_name => "Tagtical::Tag"
        
        class_eval do
          def self.taggable?
            true
          end
        end

        include Tagtical::Taggable::Core
        include Tagtical::Taggable::Collection
        include Tagtical::Taggable::Cache
        include Tagtical::Taggable::Ownership
        include Tagtical::Taggable::Related
        
      end
      
    end
  end
end 
