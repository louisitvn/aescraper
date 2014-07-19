require 'optparse'
require 'sqlite3'
require 'rubygems'
require 'active_record'
require 'mechanize'

$options = {}
parser = OptionParser.new("", 24) do |opts|
  opts.banner = "\nScraper 1.0\nAuthor: Louis (Skype: louisprm)\n\n"

  opts.on("-o", "--output SQLITE3DB", "Output SQLite3 database file") do |v|
    $options[:output] = v
  end

  opts.on("-u", "--url URL", "") do |v|
    $options[:url] = v
  end

  opts.on("-m", "--min SALE", "") do |v|
    $options[:min] = v
  end

  opts.on("-x", "--max SALE", "") do |v|
    $options[:man] = v
  end

  opts.on("-p", "--proxy FILE", "") do |v|
    $options[:proxy] = v
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
  puts "\nERROR: #{ex.message}\n\nRun ruby crawler.rb -h for help\n\n"
  exit
end

if $options[:output].nil?
  puts "\nPlease specify output file: -o\n\n"
  exit
end

if $options[:url].nil?
  puts "\nPlease specify URL: -u\n\n"
  exit
end

if $options[:url].nil?
  puts "\nPlease specify URL: -u\n\n"
  exit
end

if $options[:proxy] && !File.exists?($options[:proxy])
  puts "\nProxy file #{$options[:proxy]} does not exist\n\n"
  exit
end

$options[:min] ||= 0.0
$options[:max] ||= 999999999.9
$options[:min] = $options[:min].to_f
$options[:max] = $options[:max].to_f

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: $options[:output],
  timeout: 15000
)

class Item < ActiveRecord::Base
  
end

class Proxy < ActiveRecord::Base
  
end


# Overwrite the Mechanize class to support proxy switching
Mechanize.class_eval do 
  def try(&block)
    loop do
      begin
        r = yield(self)
        switch_proxy!
        return r
      rescue Exception => ex
        log_proxy_error!
      end
    end
  end
  
  
  #def load_proxies(path)
    #@proxies = IO.read(path).strip.split("\n").select{|line| line[/^\s*#/].nil? }.map{|i| i.split(":").map{|e| e.strip}  }.select{|i| i.count == 4}
  def load_proxies
    @proxies = Proxy.as_array

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
    puts "-- Using proxy #{proxy.values.join(':')}"
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

    puts "-- Proxy #{proxy.values.join(':')} does not work"
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

# initiate the database if not existed
MySchema.new.migrate(:change) unless File.exists?($options[:output])

class Scrape
  SITE = 'http://www.boohoo.com/'

  def initialize
    @a = Mechanize.new
    @a.user_agent_alias = 'Linux Firefox'
    if $options[:proxy]
      @a.load_proxies($options[:proxy]) 
    end
  end

  def run(url)
    current_url = url
    count = 0
    loop do
      count += 1
      puts count
      ps = @a.try do |scr|
        scr.get(current_url).parser
      end

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
    puts url

    if Item.exists?(url: url)
      puts "Already scraped"
      puts "--------------------------------------"
      return
    end

    resp = @a.try do |scr|
      scr.get(url)
    end

    ps = resp.parser
    item = Item.new
    item.url = url

    if ps.css('#itemTitle').first
      item.name = ps.css('#itemTitle').first.xpath('text()').text
      item.number_of_sales = ps.css('span.qtyTxt > span > a').first.text.gsub(/[^0-9]/, '').to_i if ps.css('span.qtyTxt > span > a').first
      item.price = ps.css('#mm-saleDscPrc').first.text.gsub(/[^0-9\.]/, '') if ps.css('#mm-saleDscPrc').first
      item.price = ps.css('#prcIsum').first.text.gsub(/[^0-9\.]/, '') if ps.css('#prcIsum').first
    elsif ps.css('div').empty?
      item.name = 'something-wrong'
    end

    unless item.ok?
      item.is_valid = "false"
      item.save
      puts "Empty PRICE or SALES"
      puts "--------------------------------------"
      return
    end
    
    item.compute_total_sales!
    puts "Price: " + item.price.to_s
    puts "Sales: " + item.number_of_sales.to_s
    puts "Total Sales: " + item.total_sales.to_s
    
    if ($options[:min]..$options[:max]) === item.total_sales
      item.is_valid = "true"
      item.save
      puts "Item save!"
      puts "--------------------------------------"
    else
      item.is_valid = "false"
      item.save
      puts "Total sale out-of-range"
      puts "--------------------------------------"
    end
  end
end

# trap Ctrl-C
trap("SIGINT") { throw :ctrl_c }

catch :ctrl_c do
  e = Scrape.new
  e.run($options[:url])
end