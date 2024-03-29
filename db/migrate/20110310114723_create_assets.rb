class CreateAssets < ActiveRecord::Migration
  def self.up
    create_table :assets do |t|
      t.references :message
      t.string :name
      t.string :content_type
      t.integer :size

      t.timestamps
    end
  end

  def self.down
    drop_table :assets
  end
end
