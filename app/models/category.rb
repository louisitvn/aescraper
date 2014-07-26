class Category < ActiveRecord::Base
  has_many :tasks, :dependent => :destroy

  validates :name, presence: true
  validates :url, presence: true, format: { with: URI.regexp, message: "is not a valid Ebay URL" }
  
end
