class CreateCategories < ActiveRecord::Migration
  def change
    create_table :categories do |t|
      t.string :name
      t.string :url
      t.boolean :with_quantity_sold, default: true

      t.timestamps
    end
  end
end
