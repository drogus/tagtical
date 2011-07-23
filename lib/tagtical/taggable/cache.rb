module Tagtical::Taggable
  module Cache
    def self.included(base)
      # Skip adding caching capabilities if table not exists or no cache columns exist
      return unless base.table_exists? && base.tag_types.any? { |context| base.column_names.include?("cached_#{context.to_s.singularize}_list") }

      base.send :include, Tagtical::Taggable::Cache::InstanceMethods
      base.extend Tagtical::Taggable::Cache::ClassMethods
      
      base.class_eval do
        before_save :save_cached_tag_list        
      end
      
      base.initialize_tagtical_cache
    end
    
    module ClassMethods
      def initialize_tagtical_cache
        tag_types.each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.caching_#{tag_type.singularize}_list?
              caching_tag_list_on?("#{tag_type}")
            end  
          RUBY
        end        
      end
      
      def acts_as_taggable(*args)
        super(*args)
        initialize_tagtical_cache
      end
      
      def caching_tag_list_on?(context)
        column_names.include?("cached_#{context.to_s.singularize}_list")
      end
    end

    module InstanceMethods      
      def save_cached_tag_list
        tag_types.each do |tag_type|
          if self.class.send("caching_#{tag_type.singularize}_list?")
            self[tag_type.tag_list_name(:cached)] = tag_list_on(tag_type).to_s if tag_list_on?(tag_type)
          end
        end
        
        true
      end
    end
  end
end
