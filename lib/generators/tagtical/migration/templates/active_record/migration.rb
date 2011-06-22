class TagticalMigration < ActiveRecord::Migration
  def self.up
    create_table :tags do |t|
      t.string :value
      t.string :type
    end

    create_table :taggings do |t|
      t.references :tag

      # You should make sure that the column created is
      # long enough to store the required class names.
      t.references :taggable, :polymorphic => true
      if Tagtical.polymorphic_tagger
        t.references :tagger, :polymorphic => true
      else
        t.integer :tagger_id
      end
      t.datetime :created_at
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
