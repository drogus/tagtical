module Tagtical
  class Tagging < ::ActiveRecord::Base #:nodoc:
    include Tagtical::ActiveRecord::Backports if ::ActiveRecord::VERSION::MAJOR < 3

    attr_accessible :tag,
                    :tag_id,
                    :taggable,
                    :taggable_type,
                    :taggable_id,
                    :tagger,
                    :tagger_id,
                    :relevance

    belongs_to :tag, :class_name => 'Tagtical::Tag'
    belongs_to :taggable, :polymorphic => true

    validates_presence_of :tag_id
    validates_uniqueness_of :tag_id, :scope => [:taggable_type, :taggable_id, :tagger_id]

    if Tagtical.config.polymorphic_tagger?
      attr_accessible :tagger_type
       belongs_to :tagger, :polymorphic => true
    else
      belongs_to :tagger, case Tagtical.config.tagger
      when Hash then Tagtical.config.tagger
      when true then {:class_name => "User"} # default to using User class.
      when String then {:class_name => Tagtical.config.tagger}
      end
    end

    before_create { |record| record.relevance ||= default_relevance }

    class_attribute :default_relevance, :instance_writer => false
    self.default_relevance = 1

    def <=>(tagging)
      relevance <=> tagging.relevance
    end

    def set_tag_target_with_relevance(tag)
      if tag
        tag.relevance = relevance
        tag[:tagger_id] = tagger_id
      end
      set_tag_target_without_relevance(tag)
    end
    alias_method_chain :set_tag_target, :relevance

  end
end