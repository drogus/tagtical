class TaggableModel < ActiveRecord::Base
  acts_as_taggable(:languages, :skills, :needs, :offerings)
  has_many :untaggable_models
end

class CachedModel < ActiveRecord::Base
  acts_as_taggable
end

class OtherTaggableModel < ActiveRecord::Base
  acts_as_taggable(:terms, :languages, :needs, :offerings)
end

class InheritingTaggableModel < TaggableModel
end

class AlteredInheritingTaggableModel < TaggableModel
  acts_as_taggable(:parts)
end

class TaggableUser < ActiveRecord::Base
  acts_as_tagger
end

class UntaggableModel < ActiveRecord::Base
  belongs_to :taggable_model
end
module Tag
  class Inheriting < Tagtical::Tag
  end
end