require 'rubygems'
require 'base64'
require 'sequel'
require 'timeout'
require 'mechanize'
require 'eventmachine'
require 'ninja/threaded'
require 'transmission-client'

Ninja.hide_in = Ninja::Threaded.new(4)

module Torrent
  class Torrents
    include Ninja
    attr_accessor :max, :t
    attr_reader :torrents
  
    def initialize
      processlist = `ps -ef | grep transmission-daemon`
      `./transmission-daemon -g ./config -w ./data -m` if not processlist =~ /\.\/transmission-daemon -g \.\/config -w \.\/data -m/    
      @db = Sequel.sqlite("#{Dir.pwd}/torrents.db")
      @max = 1
      @t = Transmission::Client.new
      @adding = false
      @torrents = nil
      run
    end
  
    def update
      Timeout::timeout(5) {
      @t.torrents do |torrents|
        begin
            $mutex.synchronize {
              mytorrents = { :downloading => [], :stopped => [], :seeding => [], :checking => [], :all => [] }
              torrents.each do |torrent|
                @db[:torrents].filter(:filename => torrent.name).update(:t_id => torrent.id)
                mytorrents[:downloading] << torrent if torrent.downloading?
                mytorrents[:stopped] << torrent if torrent.stopped?
                mytorrents[:seeding] << torrent if torrent.seeding?
                mytorrents[:checking] << torrent if torrent.checking?
                mytorrents[:all] << torrent
              end

              mytorrents[:stopped].each do |torrent|
                @db[:torrents].filter(:t_id => torrent.id).update(:status => "Waiting") if @db[:torrents].filter(:t_id => torrent.id).first[:status] != "Paused"
              end

              if mytorrents[:seeding].count > 0 then
                mytorrents[:seeding].each do |torrent|
                  @t.remove(torrent.id)
                  @db[:torrents].filter(:t_id => torrent.id).delete
                end
              end

              if mytorrents[:downloading].count < @max then
                (@max - mytorrents[:downloading].count).times do |i|
                  next if !mytorrents[:stopped][i]
                  x = mytorrents[:stopped][i].id
                  while @db[:torrents].filter(:t_id => x).first[:status] == "Paused" || @db[:torrents].filter(:t_id => x).first[:status] == "Downloading"
                    i += 1
                    z = true if not mytorrents[:stopped][i]
                    break if not mytorrents[:stopped][i]
                    x = mytorrents[:stopped][i].id
                  end
                  if not z then
                    @t.start(x)
                    @db[:torrents].filter(:t_id => x).update(:status => "Downloading")
                  end
                end
              end
    
              if mytorrents[:downloading].count > @max then
                (mytorrents[:downloading].count - @max).times do |i|
                  i = -(i+1)
                  next if !mytorrents[:downloading][i]
                  x = mytorrents[:downloading][i].id
                  @t.stop(x)
                  @db[:torrents].filter(:t_id => x).update(:status => "Waiting")
                end
              end

              mytorrents[:downloading].each do |torrent|
                percent = "%0.2f" % (torrent.percentDone * 100)
                @db[:torrents].filter(:t_id => torrent.id).update(:percent => percent.to_f, :status => "Downloading")
              end
    
              @torrents = mytorrents

              @db[:torrents].filter(:status => "Done").update(:percent => 100.0, :t_id => 9999999999)
              @db[:torrents].filter(:percent => 100.0).update(:status => "Done", :t_id => 9999999999)
              @db[:torrents].filter(:percent => nil).update(:percent => "0")
              @db[:torrents].filter(:t_id => 9999999999).delete
            }
          scan
        rescue
          puts $!
          retry
        end
      end
    }
    end
  
    def scan
      return if @adding
      $mutex.synchronize {
        torrent = @db[:torrents].filter(:added => 0).first
        return if !torrent
        begin
          a = File.open("tmp/#{torrent[:t_hash]}.torrent", 'r').read
          x = Base64.encode64(a)
          File.delete("tmp/#{torrent[:t_hash]}.torrent")
          @adding = true
          @t.add_torrent_by_data(x) do |x|
            puts x
            if x['result'] then
              if x['result'] == "duplicate torrent" then
              else
                @db[:torrents].filter(:t_hash => torrent[:t_hash]).delete
              end
            end
            if x['torrent-added'] then
              @db[:torrents].filter(:t_hash => torrent[:t_hash]).update(:added => 1, :status => "Added", :t_id => x['torrent-added']['id'].to_i, :filename => x['torrent-added']['name'])
              @t.stop(x['torrent-added']['id'].to_i)
            end
            @adding = false
          end
        rescue
          @db[:torrents].filter(:t_hash => torrent[:t_hash]).delete
          puts $!
          retry
        end
      }
    end
  
    def run
      in_background do
        EventMachine.run do
          EventMachine::add_periodic_timer(5) do
            update
          end
          EventMachine::add_periodic_timer(60*60) do
            @t = Transmission::Client.new
          end
        end
      end
    end
  end
end