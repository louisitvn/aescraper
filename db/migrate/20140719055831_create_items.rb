class CreateItems < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.text :url
      t.string :number
      t.string :name
      t.text :price

      t.timestamps
    end

    add_index :items, :url
  end
end
