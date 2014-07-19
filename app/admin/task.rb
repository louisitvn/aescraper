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
      f.input :category_id, as: :select, collection: options_for_select(Category.all.map{|c| ["#{c.name} - #{c.url}", c.id] } )
      f.input :scraping_date, as: :datepicker
      f.actions
    end
  end

  member_action :stop, :method => :get do
    t = Task.find(params[:id])
    t.stop!
    redirect_to admin_tasks_path
  end

  member_action :start, :method => :get do
    t = Task.find(params[:id])
    t.start!
    redirect_to admin_tasks_path
  end

  index do 
    selectable_column
    column :status, sortable: :status do |r|
      status_tag r.status
    end
    column 'Category' do |r|
      r.category.name
    end
    column :scraping_date
    column :progress
    column 'Action' do |r|
      if r.running?
        link_to 'Stop', stop_admin_task_path(r), method: :get
      else
        link_to 'Start', start_admin_task_path(r), method: :get
      end
    end
  end
end
