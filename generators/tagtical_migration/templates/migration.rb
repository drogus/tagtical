class TagticalMigration < ActiveRecord::Migration
  def self.up
    create_table :tags do |t|
      t.column :value, :string
      t.column :type, :string
    end
    
    create_table :taggings do |t|
      t.column :tag_id, :integer
      t.column :taggable_id, :integer
      t.column :tagger_id, :integer
      t.column :tagger_type, :string if Tagtical.polymorphic_tagger
      
      # You should make sure that the column created is
      # long enough to store the required class names.
      t.column :taggable_type, :string
      
      t.column :created_at, :datetime
    end
    
    add_index :taggings, :tag_id
    add_index :taggings, [:taggable_id, :taggable_type, :context]
    add_index :taggings, Tagtical.polymorphic_tagger ? [:tagger_id, :tagger_type] : :tagger_id
  end
  
  def self.down
    drop_table :taggings
    drop_table :tags
  end

end
