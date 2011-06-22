module Tagtical
  class Tag
    class Term < Tag

      # We abstract out the traditional usage of a tag into a subclass "Tag::Term". This frees us up
      # to do use STI and have different tags behave differently.

      include Tagtical::ActiveRecord::Backports if ::ActiveRecord::VERSION::MAJOR < 3

      alias_attribute :name, :value

      class << self
        
        ### SCOPES:

        def using_postgresql?
          connection.adapter_name == 'PostgreSQL'
        end

        def named(name)          where_name_like([name])        end
        def named_any(list)      where_name_like(list)          end
        def named_like(name)     where_name_like([name], true)  end
        def named_like_any(list) where_name_like(list,   true)  end

        def where_name_like(list, wildcard=false)
          char = "%" if wildcard
          like_operator = using_postgresql? ? 'ILIKE' : 'LIKE'
          conditions = list.map { |tag| ["name #{like_operator} ?", "#{char}#{tag.to_s}#{char}"] }
          where(conditions.size==1 ? conditions.first : conditions.map { |c| sanitize_sql(c) }.join(" OR "))
        end

        ### CLASS METHODS:

        def find_or_create_with_like_by_name(name)
          named_like(name).first || create(:name => name)
        end

        def find_or_create_all_with_like_by_value(*list)
          list = [list].flatten

          return [] if list.empty?

          existing_tags = Tag.named_any(list).all
          new_tag_names = list.reject do |name|
            name = comparable_name(name)
            existing_tags.any? { |tag| comparable_name(tag.value) == name }
          end
          created_tags  = new_tag_names.map { |name| Tag.create(:name => name) }

          existing_tags + created_tags
        end

        private

        def comparable_name(str)
          RUBY_VERSION >= "1.9" ? str.downcase : str.mb_chars.downcase
        end
        
      end

    end
  end
end
