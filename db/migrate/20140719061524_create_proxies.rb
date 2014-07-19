class CreateProxies < ActiveRecord::Migration
  def change
    create_table :proxies do |t|
      t.string :ip
      t.string :port
      t.string :username
      t.string :password
      t.string :status

      t.timestamps
    end
  end
end
