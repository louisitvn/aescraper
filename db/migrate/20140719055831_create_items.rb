class CreateItems < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.text :url
      t.string :number
      t.string :name
      t.string :condition
      t.string :seller_name
      t.string :category
      t.string :country
      t.text :price
      t.text :quantity_sold

      t.timestamps
    end

    add_index :items, :url
  end
end
