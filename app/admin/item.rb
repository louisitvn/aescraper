ActiveAdmin.register Item do

  
  # See permitted parameters documentation:
  # https://github.com/gregbell/active_admin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # permit_params :list, :of, :attributes, :on, :model
  #
  # or
  #
  # permit_params do
  #  permitted = [:permitted, :attributes]
  #  permitted << :other if resource.something?
  #  permitted
  # end

  index do 
    selectable_column
    column :name
    column :url
    
    Item.select(:price).map(&:price).inject([]){|a, k| a += k.keys }.uniq.each do |scraping_date|
      column scraping_date, class: 'text-right' do |r|
        number_to_currency r.price[scraping_date]
      end
    end
  end

  
  filter :url
  filter :name
  filter :by_name_in, label: "Exact name(s) (separated by space)", as: :string
  filter :description
  filter :condition
  filter :seller_name
  filter :category
  filter :quantity_sold

  collection_action :do_report, :method => :post do
    p params[:from]
    p params[:to]
    p params[:category]
    
    ranges = params[:from].zip(params[:to]).select{|f,t| !f.blank? && !t.blank? }
    
    csv_string = CSV.generate do |csv|    
      items = Item.all.each do |item|
        r = [item.url, item.name]
        ranges.each{|f,t|
          r << (price[t] - price[f])
          r << (price[t] - price[f])
        }
        csv << 1
      end
    end

    render text: 'AAA'
  end

  collection_action :report, :method => :get do
    @dates = Item.select(:price).map(&:price).inject([]){|a, k| a += k.keys }.uniq
  end
end
