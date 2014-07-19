class Proxy < ActiveRecord::Base
  scope :alive, -> { where(status: 'alive') }
  scope :dead, -> { where(status: 'dead') }

  def mark_as_dead!
    self.status = 'dead'
    self.save!
  end

  def self.to_array
    self.all.map{|e| [e.ip, e.port, e.username, e.password]}
  end
end
