class AddAddressPhoneToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :address_line_2, :string
    add_column :users, :phone, :string
  end

  def self.down
    remove_column :users, :address_line_2
    remove_column :users, :phone    
  end
end
