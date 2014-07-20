ActiveAdmin.register Category do
  permit_params :name, :url
  
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
    column :url do |r|
      link_to r.url, r.url
    end
    column :created_at
  end

  controller do 
    def create
      # do not go to the VIEW page after create
      create! do |format|
        format.html { redirect_to admin_categories_path }
      end
    end
  end  
  
end
