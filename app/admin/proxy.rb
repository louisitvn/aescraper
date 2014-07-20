ActiveAdmin.register Proxy do
  permit_params :ip, :port, :username, :password, :status, :hit_count, :enable
  
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
  collection_action :import, :method => :get do
    
  end

  index do 
    selectable_column
    column :ip
    column :port
    column :username
    column :password
    column :created_at
  end

  collection_action :do_import, :method => :post do
    done, failed = Proxy.import(params[:proxies])
    redirect_to admin_proxies_path, :notice => "#{done.count} proxies imported, #{failed.count} failed"
  end

  action_item(only: :index) do
    link_to "Import Proxies", import_admin_proxies_path
  end
end
