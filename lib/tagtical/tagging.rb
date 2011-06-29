module Tagtical
  class Tagging < ::ActiveRecord::Base #:nodoc:
    include Tagtical::ActiveRecord::Backports if ::ActiveRecord::VERSION::MAJOR < 3

    attr_accessible :tag,
                    :tag_id,
                    :taggable,
                    :taggable_type,
                    :taggable_id,
                    :tagger,
                    :tagger_id

    belongs_to :tag, :class_name => 'Tagtical::Tag'
    belongs_to :taggable, :polymorphic => true

    validates_presence_of :tag_id

    if Tagtical.config.polymorphic_tagger?
       validates_uniqueness_of :tag_id, :scope => [:taggable_type, :taggable_id, :tagger_id, :tagger_type]
       attr_accessible :tagger_type
       belongs_to :tagger, :polymorphic => true
    else
       validates_uniqueness_of :tag_id, :scope => [:taggable_type, :taggable_id, :tagger_id]
       belongs_to :tagger, case Tagtical.config.tagger
                           when Hash then Tagtical.config.tagger
                           when true then {:class_name => "User"} # default to using User class.
                           when String then {:class_name => Tagtical.config.tagger}
                           end
    end
      
  end
end