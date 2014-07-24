class Item < ActiveRecord::Base
  serialize :price, JSON
  serialize :quantity, JSON

  ransacker :by_name, formatter: ->(search) {
    search = search.downcase.split(/\s+/)

    data = Item.where('lower(name) IN (?)', search).all.map(&:id)
    data = data.any? ? data : nil
  } do |parent|
    parent.table[:id]
  end
end
