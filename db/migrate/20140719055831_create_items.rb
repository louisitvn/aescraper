class CreateItems < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.string :url
      t.string :number
      t.string :name
      t.float :price

      t.timestamps
    end
  end
end
