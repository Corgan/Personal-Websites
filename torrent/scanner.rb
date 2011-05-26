require 'rubygems'
require 'sequel'
require 'feed_me'
require 'mechanize'
require 'eventmachine'
require 'ninja/threaded'

Ninja.hide_in = Ninja::Threaded.new(4)

module Torrent
  class Scanner
    include Ninja
  
    def initialize
      @db = Sequel.sqlite("#{Dir.pwd}/feeds.db")
      @torrents = Sequel.sqlite("#{Dir.pwd}/torrents.db")
    
      @db.create_table? :feeds do
        primary_key :id
        String :name
        String :match
        String :url
        Time :scanned
        Time :added
      end
      
      @torrents.create_table? :torrents do
        primary_key :id
        Integer :added, :default => 0
        String :t_hash, :unique => true
        String :status
        Integer :t_id
        String :filename
        Float :percent
      end
      
      self.instance_eval "class Torrent::Scanner::Torrents < Sequel::Model(@torrents[:torrents]); end"    
      self.instance_eval "class Torrent::Scanner::Feed < Sequel::Model(@db[:feeds]); end"
      run
    end
  
    def add_feed(name, url, regex)
      f = Feed.new
      f.name = name
      f.url = url
      f.match = regex.to_s
      f.added = Time.now
      f.scanned = Time.now
      f.save
      scan_feed(f[:id])
    end
  
    def scan_feed(id)
      begin
      feed = Feed[:id => id]  
      puts "Scanning #{feed[:name]}"
      match = Regexp.new(feed[:match])
      body = Mechanize.new {|agent| agent.user_agent = "Mac Safari"; agent.history.max_size = 0 }.get(feed[:url]).body
      rss = FeedMe.parse(body)
    
      rss.entries.each do |entry|
        if entry.title =~ match
          updated_at = entry.updated_at + (60*60*1)
          if updated_at > feed[:scanned] then
            Mechanize.new {|agent| agent.user_agent = "Mac Safari"; agent.history.max_size = 0 }.get("http://localhost:9292/add?url=#{entry.url}").body
          end
        end
      end
    
      feed.update(:scanned => Time.now)
      rescue
        puts $!
        retry
      end
    end
  
    def run
      in_background do
        EventMachine.run do
          EM.add_periodic_timer(10) do
            begin
            Feed.each do |feed|
              feed.update(:scanned => feed[:added]) if !feed[:scanned]
              if Time.now > feed[:scanned]+(60*5)
                scan_feed(feed[:id])
                sleep 5
              end
            end
            rescue
              puts $!
              retry
            end
          end
        
          EventMachine::Timer.new(5) do
            #add_feed("True Blood", "http://ezrss.it/feed/", /True Blood/i)
            #add_feed("Secret Life", "http://ezrss.it/feed/", /Secret Life/i)
            #add_feed("Make It or Break It", "http://ezrss.it/feed/", /Make It or Break It/i)
            #add_feed("Pretty Little Liars", "http://ezrss.it/feed/", /Pretty Little Liars/i)
          end
        
        end
      end
    end
  end
end