class Item < ActiveRecord::Base
  serialize :price, JSON
  serialize :quantity_sold, JSON

  # @deprecated
  ransacker :by_name, formatter: ->(search) {
    search = search.downcase.split(/\s+/)

    data = Item.where('lower(name) IN (?)', search).all.map(&:id)
    data = data.any? ? data : nil
  } do |parent|
    parent.table[:id]
  end

  def average_price(f, t)
    # days = (Date.parse(t) - Date.parse(f)).to_i
    ranges = self.price.select{|k,v| k >= f && k <= t }
    return 0 if ranges.blank?
    return ranges.values.inject(0.0){|sum, i| i.blank? ? sum : sum += i.to_f}.to_f / ranges.count
  end

  def unit_increase_in_qty_sold(f, t)
    return 'N/A' if self.quantity_sold[f].blank? or self.quantity_sold[t].blank?
    return self.quantity_sold[t].to_f - self.quantity_sold[f].to_f
  end

  def percentage_increase_in_qty_sold(f, t)
    return 'N/A' if self.quantity_sold[f].blank? or self.quantity_sold[t].blank?
    return 'N/A' if self.quantity_sold[f].to_f == 0.0
    return ((self.quantity_sold[t].to_f - self.quantity_sold[f].to_f) * 100 / self.quantity_sold[f].to_f).round(2)
  end

  def percentage_increase_in_price(f, t)
    return 'N/A' if self.price[f].blank? or self.price[t].blank?
    return 'N/A' if self.price[f].to_f == 0.0
    return ((self.price[t].to_f - self.price[f].to_f) * 100.0 / self.price[f].to_f).round(2)
  end

  def self.filter(params)
    p params
    scope = self.select("*")
    scope = scope.where(number: params[:numbers].split(/[\s+]/)) if !params[:numbers].blank?
    scope = scope.where('name ilike ?', "%#{params[:name]}%") if !params[:name].blank?
    scope = scope.where('seller_name ilike ?', "%#{params[:seller_name]}%") if !params[:seller_name].blank?
    scope = scope.where(condition: params[:condition]) if !params[:condition].blank?
    scope = scope.where(:last_price => (params[:price_min].to_f..params[:price_max].to_f)) if (!params[:price_min].blank? and !params[:price_max].blank?)
    scope = scope.where(category: params[:category]) if !params[:category].blank?

    return scope.all
  end
end
