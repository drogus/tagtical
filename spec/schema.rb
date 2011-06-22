ActiveRecord::Schema.define :version => 0 do
  create_table "taggings", :force => true do |t|
    t.integer  "tag_id",        :limit => 11
    t.integer  "taggable_id",   :limit => 11
    t.string   "taggable_type"
    t.datetime "created_at"
    t.column :tagger_id, :integer
    t.column :tagger_type, :string if Tagtical.polymorphic_tagger
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type", "context"], :name => "index_taggings_on_taggable_id_and_taggable_type_and_context"

  create_table "tags", :force => true do |t|
    t.column :value, :string
    t.column :type, :string
  end
  
  create_table :taggable_models, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
  end
  
  create_table :untaggable_models, :force => true do |t|
    t.column :taggable_model_id, :integer
    t.column :name, :string
  end
  
  create_table :cached_models, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
    t.column :cached_tag_list, :string
  end
  
  create_table :taggable_users, :force => true do |t|
    t.column :name, :string
  end
  
  create_table :other_taggable_models, :force => true do |t|
    t.column :name, :string
    t.column :type, :string
  end
end
