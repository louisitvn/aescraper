class Item < ActiveRecord::Base
  serialize :price, JSON
end
