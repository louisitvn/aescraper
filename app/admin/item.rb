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
end
