module Tagtical
  class Tag < ::ActiveRecord::Base

    # Create subclasses for tags
    self.abstract_class = true

    attr_accessible :value

    ### ASSOCIATIONS:

    has_many :taggings, :dependent => :destroy, :class_name => 'Tagtical::Tagging'

    ### VALIDATIONS:

    validates_presence_of :value
    validates_uniqueness_of :value

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(Tag) && name == object.name)
    end

    def to_s
      value
    end

    def count
      read_attribute(:count).to_i
    end

  end
end
