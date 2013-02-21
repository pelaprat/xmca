class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.references :yarn
      t.references :person
      t.string :subject

      t.timestamps
    end
  end

  def self.down
    drop_table :messages
  end
end
