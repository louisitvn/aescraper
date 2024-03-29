# export DATABASE_URL="postgres://postgres:postgres@localhost:5432/delfd2f62lj1or"

require 'optparse'
require 'rubygems'
require 'active_record'
require 'mechanize'
require 'logger'

$logger = Logger.new('/tmp/scraper.log', 0, 10*1024*1024)


$options = {}
parser = OptionParser.new("", 24) do |opts|
  opts.banner = "\nScraper 1.0\nAuthor: Louis (Skype: louisprm)\n\n"

  opts.on("-u", "--url URL", "") do |v|
    $options[:url] = v
  end

  opts.on("-d", "--delay DELAY", "DELAY in millisecond") do |v|
    $options[:delay] = v
  end

  opts.on("-t", "--task ID", "") do |v|
    $options[:task] = v
  end

  opts.on_tail('-h', '--help', 'Displays this help') do
		puts opts, "", help
    exit
	end
end

def help
  return <<-eos

GUIDELINE
-------------------------------------------------------
The scraper package includes two scripts

  1. scrape.rb: scrape data from the internet and store to a local database file
  2. export.rb: read the local database and generate the CSV output

Procedures:

  1. Run the scrape script and store scraped data to local database file main.db
	   
        ruby scrape.rb --output=main.db \\
                       --url="http://www.ebay.com.au/sch/i.html?_from=R40&_sacat=0&_nkw=guitar&_pgn=10&_skc=450&rt=nc" \\
                       --min=200 \\
                       --proxy=proxy.txt

  2. After the scraper script is done, run the export.rb script to read the main.db
     database and generate the CSV file data.xls

        ruby export.rb --input=main.db --output=/tmp/data.csv

Notes:

- The scrape.rb script supports resuming. Just run the script over and over again
  in case of any failure (due to internet connection problem for instance)to have
  it start from where it left off. Be sure to specify the same output database file
- As the scrape script stores items ony-by-one, you can run the export script
  even when the scraping process is not complete yet. Then it will export available
  items in the local database
 
eos
end

begin
  parser.parse!
rescue SystemExit => ex
  exit
rescue Exception => ex
  # puts "\nERROR: #{ex.message}\n\nRun ruby crawler.rb -h for help\n\n"
  exit
end

if $options[:url].nil?
  # puts "\nPlease specify URL: -u\n\n"
  exit
end

if $options[:task].nil?
  # puts "\nPlease specify task: -t\n\n"
  exit
end

$options[:delay] ||= 0
$options[:delay] = $options[:delay].to_i/1000

uri = URI.parse(ENV["DATABASE_URL"])

class String
  def floatify
    return self.strip.gsub(/[^0-9\.]/, '').to_f
  rescue Exception => exp
    return 0.0
  end
end

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  database: uri.path.gsub(/^\//, ""),
  username: uri.user,
  password: uri.password,
  port: uri.port,
  host: uri.host,
  timeout: 15000
)

class Item < ActiveRecord::Base
  serialize :price, JSON
  serialize :quantity_sold, JSON
  serialize :extra, JSON
  serialize :postage, JSON
end

class Category < ActiveRecord::Base
end

class Task < ActiveRecord::Base
  belongs_to :category
  RUNNING = 'running'
  DEAD = 'dead'
  DONE = 'done'
  STOPPED = 'stopped'
  FAILED = 'failed'

  def log(msg)
    self.progress ||= ''
    self.progress += "#{Time.now.to_s}: #{msg}\n"
  end
end

$task = Task.find($options[:task])

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


# Overwrite the Mechanize class to support proxy switching
Mechanize.class_eval do 
  def try(&block)
    loop do
      begin
        r = yield(self)
        switch_proxy!
        return r
      rescue Exception => ex # cần làm rõ do Exception nào mà mark-proxy-as-dead, có thể có tr hợp lỗi do website
        log_proxy_error!
      end
    end
  end
  
  
  #def load_proxies(path)
    #@proxies = IO.read(path).strip.split("\n").select{|line| line[/^\s*#/].nil? }.map{|i| i.split(":").map{|e| e.strip}  }.select{|i| i.count == 4}
  def load_proxies
    @proxies = Proxy.alive.to_array    
    @proxy_errors = {}
    @proxies.each do |i|
      @proxy_errors[i[0]] = 0
    end
    @current_proxy_index = 0
    @max_proxy_error = 3
    switch_proxy!
  end

  def _proxies
    @proxies || []
  end

  def _proxy_errors
    @proxy_errors
  end

  def load_user_agents(path)
    @agents = File.read(path).split("\n").select{|line| line[/^\s*#/].nil? && !line.nil? }.map{|line| line.strip }
  end
  
  def switch_proxy!
    set_proxy(*next_proxy)
    if @proxy_addr.nil?
      # puts "Direct connection"
    else
      # puts "-- Using proxy #{proxy.values.join(':')}"
    end
  end

  def switch_user_agent!
    self.user_agent = @agents.sample unless @agents.nil? or @agents.empty?
  end

  def proxy
    return {proxy_addr: @proxy_addr, proxy_port: @proxy_port, proxy_user: @proxy_user, proxy_pass: @proxy_pass}
  end

  def mark_current_proxy_as_dead!
    return if @proxies.nil? || @proxies.empty?
    # @todo: checking addr only is enough?
    @proxies.delete_if {|i|
      i[0] == @proxy_addr
    }

    # đánh dấu dead
    pr = Proxy.find_by(ip: @proxy_addr)
    pr.mark_as_dead!

    # puts "-- Proxy #{proxy.values.join(':')} does not work"
    switch_proxy!
  end

  def log_proxy_error!
    unless @proxy_addr
      # puts "-- direct connection --"
      return
    end

    @proxy_errors[@proxy_addr] += 1
    if @max_proxy_error && @proxy_errors[@proxy_addr] >= @max_proxy_error
      mark_current_proxy_as_dead!
    end
  end

  def max_proxy_error=(value)
    @max_proxy_error = value.to_i
  end

  private
  def next_proxy
    return [nil, nil, nil, nil] if @proxies.nil? or @proxies.empty?

    @current_proxy_index = 0 if @current_proxy_index >= @proxies.count
    proxy = @proxies[@current_proxy_index]
    @current_proxy_index += 1
    @current_proxy_index = 0 if @current_proxy_index >= @proxies.count      
    return proxy
  end
end

class Scrape
  def initialize
    @a = Mechanize.new
    @a.user_agent_alias = 'Linux Firefox'
    @a.load_proxies
  end

  def run(url)
    current_url = url
    count = 0
    loop do
      count += 1
      ps = @a.try do |scr|
        scr.get(current_url).parser
      end
      $task.update_attributes(progress: "Scraping...")
      item_urls = ps.css('#ResultSetItems > table div.ittl h3 a').map{|a| a.attributes['href'].value }
      if item_urls.empty?
        item_urls = ps.css('table.fgdt div.ititle h3 > a.vip').map{|a| a.attributes['href'].value }
      end

      break if item_urls.empty?

      item_urls.each do |item_url|
        get(item_url)
      end
      
      # next page
      next_page = ps.css('a.pg.curr').text.strip.to_i + 1
      next_page_link = ps.css('a.pg').select{|a| a.text.strip.to_i == next_page}.first
      if next_page_link
        current_url = next_page_link.attributes['href'].value
      else
        break
      end
    end
  end

  def get(url)
    $logger.info("scraping " + url)

    item = Item.where(url: url).first
    if item && item.price && item.price[$task.scraping_date]
      return
    end

    if item
      
    else
      item = Item.new
      item.price = {}
      item.postage = {}
      item.quantity_sold = {}
    end
    
    File.open('/tmp/logme', 'a') {|f| f.write(url)}

    resp = @a.try do |scr|
      scr.get(url)
    end

    ps = resp.parser
    unless ps.css('span.qtyTxt > span > a').first
      return
    end

    item.url = url

    if ps.css('#itemTitle').first
      item.name = ps.css('#itemTitle').first.xpath('text()').text
      item.number = ps.css('div.u-flL.iti-act-num').first.text.strip
      item.cat_url = $task.category.url
      item.condition = ps.css('#vi-itm-cond').first.text.strip if ps.css('#vi-itm-cond').first
      item.category = ps.css('h2 > ul > li').map{|li| li.text.strip}.join(" ")
      item.seller_name = ps.css('span.mbg-nw').first.text.strip
      item.location = ps.css('div.sh-loc').first.xpath('text()').text.strip if ps.css('div.sh-loc').first
      item.quantity_sold[$task.scraping_date] = ps.css('span.qtyTxt > span > a').first.text.gsub(/[^0-9]/, '').to_i if ps.css('span.qtyTxt > span > a').first
      item.feedback = ps.css('span.mbg-l > a').first.text.strip if ps.css('span.mbg-l > a').first
      item.price[$task.scraping_date] = ps.css('#mm-saleDscPrc').first.text.floatify if ps.css('#mm-saleDscPrc').first
      item.price[$task.scraping_date] = ps.css('#prcIsum').first.text.floatify if ps.css('#prcIsum').first

      if item.price[$task.scraping_date]
        item.postage[$task.scraping_date] = 0.0
        item.last_price = item.price[$task.scraping_date]
      end

      item.postage[$task.scraping_date] = ps.css('#fshippingCost > span').first.text.strip.floatify if ps.css('#fshippingCost > span').first
      item.extra = Hash[ps.css('div.itemAttr div.section td.attrLabels').map{|td| [td.text.strip.gsub(/:$/, ''), td.next_element.text.strip]}]
    elsif ps.css('div').empty?
      item.name = 'something-wrong'
    end
    
    item.save
    sleep $options[:delay]
  end
end

# trap Ctrl-C
trap("SIGINT") { throw :ctrl_c }

catch :ctrl_c do
  begin
    $task.update_attributes(status: Task::RUNNING, progress: 'Starting...')
    e = Scrape.new
    e.run($options[:url])
    $task.update_attributes(status: Task::DONE, progress: '100%')
  rescue Exception => ex
    $task.update_attributes(status: Task::FAILED, progress: "Something went wrong, please check your proxies\r\n#{ex.message}\r\nBacktrace:\r\n" + ex.backtrace.join("\r\n"))
  end
end