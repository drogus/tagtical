module Tagtical
  module Taggable
    def taggable?
      false
    end

    class Sticker

      acts_as_taggable(:colors, :terms)
    end

    ##
    # Make a model taggable on specified contexts.
    #
    # @param [Array] tag_types An array of taggable contexts
    #
    # Example:
    #   module Tag
    #     class Language < Tagtical::Tag::Term
    #     end
    #     class Skill < Tagtical::Tag::Term
    #     end
    #   end
    #   class User < ActiveRecord::Base
    #     acts_as_taggable :languages, :skills
    #   end
    def acts_as_taggable(*tag_types)
      tag_types << :term if tag_types.empty?
      tag_types = tag_types.to_a.flatten.compact.map(&:to_sym)

      if taggable?
        write_inheritable_attribute(:tag_types, (self.tag_types + tag_types).uniq)
      else
        write_inheritable_attribute(:tag_types, tag_types)
        class_inheritable_reader(:tag_types)
        
        class_eval do
          has_many :taggings, :as => :taggable, :dependent => :destroy, :include => :tag, :class_name => "Tagtical::Tagging"
          has_many :tags, :through => :taggings, :class_name => "Tagtical::Tag"

          def self.taggable?
            true
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
end
