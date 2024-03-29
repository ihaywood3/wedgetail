class CreateConditions < ActiveRecord::Migration
  def self.up
    create_table :conditions do |t|
      t.string :name
      t.string :abbreviation

      t.timestamps
    end
  end

  def self.down
    drop_table :conditions
  end
end
