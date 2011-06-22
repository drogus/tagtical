class TaggableModel < ActiveRecord::Base
  acts_as_taggable
  tagtical :languages
  tagtical :skills
  tagtical :needs, :offerings
  has_many :untaggable_models
end

class CachedModel < ActiveRecord::Base
  acts_as_taggable
end

class OtherTaggableModel < ActiveRecord::Base
  tagtical :tags, :languages
  tagtical :needs, :offerings
end

class InheritingTaggableModel < TaggableModel
end

class AlteredInheritingTaggableModel < TaggableModel
  tagtical :parts
end

class TaggableUser < ActiveRecord::Base
  acts_as_tagger
end

class UntaggableModel < ActiveRecord::Base
  belongs_to :taggable_model
end