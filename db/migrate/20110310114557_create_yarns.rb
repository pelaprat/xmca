class CreateYarns < ActiveRecord::Migration
  def self.up
    create_table :yarns do |t|
      t.string :name
      t.integer :items
      t.references :person

      t.timestamps
    end
  end

  def self.down
    drop_table :yarns
  end
end
