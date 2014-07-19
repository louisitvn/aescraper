ActiveAdmin.register Task do
  permit_params :url, :status, :scraping_date, :category_id, :progress, :pid
  
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

  form do |f|
    f.inputs Task.model_name.human do 
      f.input :category_id, as: :select, collection: options_for_select(Category.all.map{|c| ["#{c.url} - #{c.url}", c.id] } )
      f.input :scraping_date, as: :datepicker
      f.actions
    end
  end
  
end
