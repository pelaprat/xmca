class CreateBodies < ActiveRecord::Migration
  def self.up
    create_table :bodies do |t|
      t.references :message
      t.integer :level
      t.text :original
      t.text :formatted

      t.timestamps
    end
  end

  def self.down
    drop_table :bodies
  end
end
