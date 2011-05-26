#!/usr/bin/env ruby

require 'rubygems'
require 'sequel'
require 'crack'
require 'highline/system_extensions'
require 'eventmachine'
require 'mechanize'
require 'optparse'
require 'ostruct'

include HighLine::SystemExtensions

$factions = ["Alliance", "Horde", "Neutral"]

module Titan
  class Scanner
    attr_accessor :auctions

    def initialize()
      # Start looking for the One. (lol neo dies)
      @agent_smith = Mechanize.new {|agent| agent.user_agent = "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2.4) Gecko/20100513 Firefox/3.6.4"; agent.history.max_size = 0 }
			
      @horde = {};
      @alliance = {};
      
      # Load Database and get auction count
      @db = Sequel.sqlite("#{Dir.pwd}/../../econ.db")
      @db.create_table? :auctions do
        primary_key :auc
        Integer :id, :type => Integer
        String :name
        String :icon
        Integer :buyout
        Integer :bid
        Integer :ppubuy
        Integer :ppubid
        String :seller
        Integer :quant
        Integer :qual
        Time :timestamp
        String :server
        Integer :faction
      end
      
      @db.create_table? :servers do
        primary_key :id
        String :server
        Integer :alliance
        Integer :horde
        Integer :neutral
      end
      
      @db.create_table? :characters do
        primary_key :id, :type => Integer
        String :server
        String :name
        Integer :faction
      end
      
      @db.create_table? :items do
        primary_key :id
        String :name
        Integer :qual
        String :icon
      end
      
      @auctions = @db[:auctions]
      @servers = @db[:servers]
      @characters = @db[:characters]
      @items = @db[:items]
    end
    
    def login(user, pass)
      puts "Logging into #{user}"
      # I love you Mechanize.
      @agent_smith.get("http://www.wowarmory.com/auctionhouse/") do |page|
        login_result = page.form_with(:name => "loginForm") do |login|
          login.accountName = user
          login.password = pass
        end.submit
      end
      
      # Get account status
      account
    end
    
    def account
      puts "Getting account status."
      data = @agent_smith.get("http://www.wowarmory.com/login-status.xml")
      username = Crack::XML.parse(data.body)['page']['loginStatus']['username']
      puts "Logged into #{username}"
      username
    end

    def change_char(r, f)
      x = ['a', 'h', 'n']
      case f
      when "0"
        cn = @alliance[r]
      when "1"
        cn = @horde[r]
      when "2"
        cn = (@horde[r] ? @horde[r] : @alliance[r])
      else
        cn = (@horde[r] ? @horde[r] : @alliance[r])
        f = (@horde[r] ? "0" : "1")
      end
      puts("Using #{cn} of #{r} to search the #{$factions[f.to_i]} auction house.")
      data = @agent_smith.post("http://www.wowarmory.com/vault/character-select-submit.json", { 'cn' => cn, 'r' => r })
      tmp = Crack::JSON.parse(data.body)
      data = @agent_smith.get("http://www.wowarmory.com/auctionhouse/faction.json?f=#{x[f.to_i]}")
      tmp = Crack::JSON.parse(data.body)
    end
    
    def char
      path = "/vault/character-select.xml?rhtml=n"
      data = @agent_smith.get("http://www.wowarmory.com#{path}")
      tmp = Crack::XML.parse(data.body)
      horde = []
      alliance = []
      
      tmp['page']['characters']['character'].each do |x|
        horde << x if x['factionId'] == "1"
        alliance << x if x['factionId'] == "0"
      end
      horde.each { |x|
        @horde[x['realm']] = x['name'] if not @horde[x['realm']]
      }
      alliance.each { |x|
        @alliance[x['realm']] = x['name'] if not @alliance[x['realm']]
      }
    end
    
    def scan
      count = 0
      while true do
        count += 50
        
        begin
        path = "/auctionhouse/search/?sort=buyout&reverse=true&qual=0&pageSize=50&end=#{count}&start=#{count-50}&rhtml=n"
        data = @agent_smith.get("http://www.wowarmory.com#{path}")
        tmp = Crack::XML.parse(data.body)
        rescue
          retry
        end
        
        # Retries the page if an error occurs
        if tmp['page']['error'] then
          puts "Not logged in, doing so now." if tmp['page']['error']['code'] == "10005"
          login if tmp['page']['error']['code'] == "10005"
          puts "Error #{tmp['page']['error']['code']}."
          count -= 50
          next
        end
      
        puts("Scanning page #{count/50}")

        # This means that there aren't any more auctions left to search, so start from the begining.
        if tmp['page']['auctionSearch']['auctions'] == nil then
          puts("Done Scanning.")
          return "done";
        end
          
        tmp['page']['auctionSearch']['auctions']['aucItem'].each do |x|
          next if x['seller'] == "???"
          puts("[#{x['n']}]x#{x['quan']} - #{x['buy']} buy - #{x['bid']} bid") if not @auctions[:auc=>x['auc']]
          
          begin
          @auctions.insert(
            :auc => x['auc'],
            :id => x['id'],
            :name => x['n'],
            :icon => x['icon'],
            :buyout => x['buy'],
            :bid => x['bid'],
            :ppubuy => (x['ppuBuy'] ? x['ppuBuy'] : x['buy']),
            :ppubid => (x['ppuBid'] ? x['ppuBid'] : x['bid']),
            :seller => x['seller'],
            :quant => x['quan'],
            :qual => x['qual'],
            :timestamp => Time.now,
            :server => tmp['page']['command']['r'],
            :faction => tmp['page']['command']['f']
          ) if not @auctions[:auc=>x['auc']]
          
          @items.insert(:id => x['id'], :name => x['n'], :icon => x['icon'], :qual => x['qual']) if not @items[:id=>x['id']]
          @servers.insert(:server => tmp['page']['command']['r'], :alliance => 0, :horde => 0, :neutral => 0) if not @servers[:server=>tmp['page']['command']['r']]
          @servers.filter(:server=>tmp['page']['command']['r']).update(:alliance => 1) if tmp['page']['command']['f'].to_i == 0 && @servers.first(:server=>tmp['page']['command']['r'])[:alliance] == 0
          @servers.filter(:server=>tmp['page']['command']['r']).update(:horde => 1) if tmp['page']['command']['f'].to_i == 1 && @servers.first(:server=>tmp['page']['command']['r'])[:horde] == 0
          @servers.filter(:server=>tmp['page']['command']['r']).update(:neutral => 1) if tmp['page']['command']['f'].to_i == 2 && @servers.first(:server=>tmp['page']['command']['r'])[:neutral] == 0
          @characters.insert(:server => tmp['page']['command']['r'], :name => x['seller'], :faction => tmp['page']['command']['f']) if not @characters.first(:server=>tmp['page']['command']['r'], :faction => tmp['page']['command']['f'], :name => x['seller'])
        rescue
          retry
        end
        end
        sleep 0.5
      end
    end
  end
end

EventMachine::run do
  options = OpenStruct.new
    OptionParser.new do |opts|
      opts.banner = "Usage: scanner.rb [options]"
      
      opts.on('-u', '--username USERNAME', 'Use this username') do |user|
        options.user = user
      end

      opts.on('-p', '--password PASSWORD', 'Use this password') do |pass|
        options.pass = pass
      end

      opts.on('-r', '--realm REALM', 'Scan REALM') do |realm|
        options.realm = realm
      end
      
      opts.on('-f', '--faction FACTIONID', 'Faction id. 0 = Alliance. 1 = Horde') do |faction|
        options.faction = faction
      end
      
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end.parse!
    
    if !options.realm || !options.faction || !options.user || !options.pass then
      puts "WRONG ARGUMENTS LOL, USE -h"
      exit
    end
    
    scanner = Titan::Scanner.new
    scanner.login(options.user, options.pass)
    scanner.char
    scanner.change_char(options.realm, options.faction)
    while true do
      scanner.scan
    end
end
