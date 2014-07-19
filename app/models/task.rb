class Task < ActiveRecord::Base
  PATH = File.join(Rails.root, 'lib/ebay_scraper.rb')

  def running?
    begin
      Process.kill(0, self.pid.to_i)
      return true
    rescue
      return false
    end
  end

  def resume
    run()
  end

  def start
    resume()
  end

  def restart
    run()
  end

  def kill
    Process.kill 9, self.pid.to_i
  end

  private
  def run
    if self.running?
      # already running
    else
      process = IO.popen("ruby #{PATH} -u \"#{self.url}\"")
      Process.detach(process.pid)
      self.pid = process.pid
      self.save
    end
  end
end
