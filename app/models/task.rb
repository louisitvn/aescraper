class Task < ActiveRecord::Base
  belongs_to :category
  
  validates :category_id, presence: true
  validates :scraping_date, presence: true
  
  NEW = 'new'
  RUNNING = 'running'
  DONE = 'done'
  STOPPED = 'stopped'
  FAILED = 'failed'

  PATH = File.join(Rails.root, 'lib/ebay_scraper.rb')

  before_create :set_status

  def set_status
    self.status = NEW
  end

  def update_status!
    if !self.running? && self.status == RUNNING
      self.update_attributes(status: STOPPED)
    end
  end

  def running?
    return false unless self.pid
    begin
      Process.kill(0, self.pid.to_i)
      return true
    rescue
      return false
    end
  end

  def resume!
    run!()
  end

  def start!
    run!()
  end

  def restart!
    run!()
  end

  def stop!
    if self.running? && self.status = RUNNING
      begin
        Process.kill 9, self.pid.to_i
        self.status = STOPPED
        self.progress = 'Terminated'
        self.save
      rescue Exception => ex
        # @todo what goes here?
      end
    elsif self.running? && self.status != RUNNING
      begin
        Process.kill 9, self.pid.to_i
        self.status = STOPPED
        self.save
      rescue Exception => ex
        # @todo what goes here?
      end
    elsif self.status = RUNNING
      self.status = STOPPED
      self.save
    else
      raise "Already stopped"
    end
  end

  private
  def run!
    if self.running?
      # already running
    else
      self.status = RUNNING
      self.save
      delay = Setting.find_by_name('DELAY').value || 0
      cmd = "ruby #{PATH} -d #{delay} -t #{self.id} -u \"#{self.category.url}\""
      process = IO.popen(cmd)
      puts cmd, "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      Process.detach(process.pid)
      self.pid = process.pid
      self.save
    end
  end
end
