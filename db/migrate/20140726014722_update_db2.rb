class UpdateDb2 < ActiveRecord::Migration
  def change
    change_column :items, :condition, :text
    change_column :items, :seller_name, :text
    change_column :items, :location, :text
    change_column :items, :feedback, :text
    change_column :items, :category, :text
    change_column :items, :country, :text
  end
end
