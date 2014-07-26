ActiveAdmin.register Item do
  actions :all, :except => [:new]
  
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
    column :number do |r|
      link_to r.number, r.url, target: '_new'
    end
    column :name
    column :seller_name
    column :condition
    column :category
    column :feedback
    
    Item.select(:price).map(&:price).inject([]){|a, k| a += k.keys }.uniq.sort.each do |scraping_date|
      column(raw("Price<br/>#{scraping_date}"), class: 'text-right') do |r|
        number_to_currency r.price[scraping_date]
      end
      column(raw("Qty<br/>#{scraping_date}"), class: 'text-right') do |r|
        r.quantity_sold[scraping_date]
      end
    end
  end

  collection_action :do_report, :method => :post do
    items = Item.filter(params[:item])
    
    ranges = params[:item][:from].zip(params[:item][:to]).select{|f,t| !f.blank? && !t.blank? }
    csv_string = CSV.generate do |csv|
      headers = []
      ranges.each{|f,t|
        headers += ["Date Range # #{f} - #{t}", nil, nil, nil]
      }

      subheaders = []
      attrs = items.extra_keys.uniq
      ranges.each{|f,t|
        subheaders += ['Average Total Price', 'Unit increase in quantity sold', '% Increase in quantity sold', '% Change in total price']
      }
      

      subheaders += ['Description', 'Category', 'Date Added', 'Seller Name', 'Feedback', 'Number']
      subheaders += attrs

      csv << headers
      csv << subheaders

      items.each do |item|
        r = []
        ranges.each{|f,t|
          r << item.average_total_price(f, t)
          r << item.unit_increase_in_qty_sold(f, t)
          r << item.percentage_increase_in_qty_sold(f, t)
          r << item.percentage_increase_in_total_price(f, t)
        }

        r << item.name # name = descrpition
        r << item.category
        r << item.created_at
        r << item.seller_name
        r << item.feedback
        r << item.number

        attrs.each { |f|
          r << item.extra[f]
        }

        csv << r
      end
    end

    send_data csv_string, :filename => "data-#{Time.now.to_i.to_s}.csv"
    #render :text => items.map{|i| i.number }.to_s
  end

  action_item(only: :index) do
    link_to "Export To CSV", report_admin_items_path
  end

  collection_action :report, :method => :get do
    @dates = Item.select(:price).map(&:price).inject([]){|a, k| a += k.keys }.uniq
  end
end
