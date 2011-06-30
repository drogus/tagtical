### START Tag Subclasses ###

module Tagtical
  class Tag
    class Language < Tagtical::Tag
    end
    class PartTag < Tagtical::Tag
    end
  end
end
module Tag
  class Skill < Tagtical::Tag
  end
  class Craft < Skill # Multiple levels of inheritance
  end
end
class NeedTag < Tagtical::Tag # Tag subclass ending in "Tag"
end
class Offering < Tagtical::Tag # Top level
end

### END Tag Subclasses ###

class TaggableModel < ActiveRecord::Base
  acts_as_taggable(:languages, :skills, :crafts, :needs, :offerings)
  has_many :untaggable_models
end

class CachedModel < ActiveRecord::Base
  acts_as_taggable
end

class OtherTaggableModel < ActiveRecord::Base
  acts_as_taggable(:languages, :needs, :offerings)
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
