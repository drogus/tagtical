require "active_record"
require "action_view"
require "active_support/hash_with_indifferent_access"
require "active_support/ordered_options"

module Tagtical

  # Place a tagtical.yml file in the config directory to control settings
  mattr_accessor :config
  self.config = ActiveSupport::InheritableOptions.new(ActiveSupport::HashWithIndifferentAccess.new.tap do |hash|
    require 'yaml'
    path = Rails.root.join("config", "tagtical.yml") rescue ""
    hash.update(YAML.load_file(path)) if File.exists?(path)
    # If tagger association options were not provided, then use the polymorphic_tagger association.
    hash.reverse_merge!(
      :polymorphic_tagger? => !hash[:tagger]
    )
  end)

end

$LOAD_PATH.unshift(File.dirname(__FILE__))

require "tagtical/compatibility/active_record_backports" if ActiveRecord::VERSION::MAJOR < 3
require "tagtical/compatibility/ar_hacks"

require "tagtical/taggable"
require "tagtical/taggable/core"
require "tagtical/taggable/collection"
require "tagtical/taggable/cache"
require "tagtical/taggable/ownership"
require "tagtical/taggable/related"

require "tagtical/acts_as_tagger"
require "tagtical/tag"
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
