class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
      t.string :pid
      t.string :status
      t.string :scraping_date
      t.string :progress

      t.timestamps
    end

    add_reference :tasks, :category, index: true
  end
end
