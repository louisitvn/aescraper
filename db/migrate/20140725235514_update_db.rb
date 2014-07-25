class UpdateDb < ActiveRecord::Migration
  def change
    change_column :tasks, :progress, :text
  end
end
