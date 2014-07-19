json.array!(@items) do |item|
  json.extract! item, :id, :url, :number, :name, :price
  json.url item_url(item, format: :json)
end
