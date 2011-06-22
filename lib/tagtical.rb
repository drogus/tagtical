require "active_record"
require "action_view"

$LOAD_PATH.unshift(File.dirname(__FILE__))

require "tagtical/compatibility/active_record_backports" if ActiveRecord::VERSION::MAJOR < 3

require "tagtical/taggable"
require "tagtical/taggable/core"
require "tagtical/taggable/collection"
require "tagtical/taggable/cache"
require "tagtical/taggable/ownership"
require "tagtical/taggable/related"

require "tagtical/acts_as_tagger"
require "tagtical/tag/base"
require "tagtical/tag_list"
require "tagtical/tags_helper"
require "tagtical/tagging"

$LOAD_PATH.shift

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend Tagtical::Taggable
  ActiveRecord::Base.send :include, Tagtical::Tagger
end

if defined?(ActionView::Base)
  ActionView::Base.send :include, Tagtical::TagsHelper
end

module Tagtical
  extend self

  # If set to false, then the tagger_id field must be mapped to only one AR model.
  #
  #
  attr_accessor :polymorphic_tagger
  self.polymorphic_tagger = false

end