require 'rubygems'
require 'find'
require 'haml'
require 'sequel'
require 'bencodr'
require 'downlow'
require 'fileutils'
require 'digest/sha1'
require 'sinatra/base'
require 'thread'
require './torrents'
require './scanner'

module Torrent
  class MyApp < Sinatra::Base
    set :app_file, __FILE__
    
    $mutex = Mutex.new

    DB = Sequel.sqlite("#{Dir.pwd}/torrents.db")
    T = Torrent::Torrents.new
    S = Torrent::Scanner.new
    AGENT = Mechanize.new {|agent| agent.user_agent = "Mac Safari"; agent.history.max_size = 0 }

    DB.create_table? :torrents do
      primary_key :id
      Integer :added, :default => 0
      String :t_hash, :unique => true
      String :status
      Integer :t_id
      String :filename
      Float :percent
    end

    class Torrent < Sequel::Model
    end
  
    helpers do
      def find(dir)
        return [dir] if not File.directory?(dir)
        x = []
        Find.find("./data/#{dir}") do |f| x << f; end
        x
      end
    
      def pretty_bytes(bytes)
        k = 2.0**10
        m = 2.0**20
        g = 2.0**30
        max_digits=3
        value, suffix, precision = case bytes
          when 0...k
            [bytes, 'B', 0]
          else
            value, suffix = case bytes
              when k...m then [bytes / k, 'kB']
              when m...g then [bytes / m, 'MB']
              else [bytes / g, 'GB']
            end
            used_digits = case value
              when   0...10   then 1
              when  10...100  then 2
              when 100...1024 then 3
            end
            leftover_digits = max_digits - used_digits
            [value, suffix, leftover_digits > 0 ? leftover_digits : 0]
        end
        "%.#{precision}f#{suffix}" % value
      end
    end

    get '/' do
      $mutex.synchronize {
        @torrents = DB[:torrents]
        @x = T.torrents[:all] if T.torrents
        haml :index
      }
    end
  
    add = lambda do
      if params[:hash] then
        t_hash = params[:hash]
        info = AGENT.get("http://zoink.it/torrent/#{t_hash.upcase}.torrent").body
        file = File.open("tmp/#{t_hash}.torrent", 'w') { |f| f.write(info) }
      end
    
      if params[:url] then
        url = params[:url].gsub('[', '%5B').gsub(']', '%5D')
        d = Downlow::Fetcher.fetch(url)
        t = File.bdecode(d)
        t_hash = Digest::SHA1.hexdigest t['info'].bencode
        info = d.read
        File.delete(d)
        file = File.open("tmp/#{t_hash}.torrent", 'w') { |f| f.write(info) }
      end
    
      if params[:file] then
        t = File.bdecode(params[:file][:tempfile])
        t_hash = Digest::SHA1.hexdigest t['info'].bencode
        info = File.open(params[:file][:tempfile]).read
        file = File.open("tmp/#{t_hash}.torrent", 'w') { |f| f.write(info) }
      end
    
      redirect '/' if not t_hash
      u = Torrent.new
      u.t_hash = t_hash
      $mutex.synchronize {
          u.save
      }
      "Added!"
    end
  
    get '/add', &add
    post '/add', &add
  
    get '/torrent/:id/delete' do
      $mutex.synchronize {
        t = DB[:torrents].filter(:t_id => params[:id])
        if t
          t.delete if t
          T.t.remove(params[:id].to_i, true)
        end
      "Deleted"
      }
    end
  
    get '/torrent/:hash/delete_h' do
      $mutex.synchronize {
        t = DB[:torrents].filter(:t_hash => params[:hash])
        if t
          t.delete if t
        end
      "Deleted"
      }
    end
  
    get '/torrent/:id/start' do
      $mutex.synchronize {
        t = DB[:torrents].filter(:t_id => params[:id])
        if t
          t.update(:status => "Waiting")
        end
        "Started"
      }
    end
  
    get '/torrent/:id/forcestart' do
      $mutex.synchronize {
        t = DB[:torrents].filter(:t_id => params[:id])
        if t
          t.update(:status => "Downloading")
          T.t.start(params[:id].to_i)
        end
        "Started"
      }
    end
  
    get '/torrent/:id/pause' do
      $mutex.synchronize {
        t = DB[:torrents].filter(:t_id => params[:id])
        if t
          t.update(:status => "Paused") 
          T.t.stop(params[:id].to_i)
        end
        "Paused #{params[:id]}"
      }
    end
  
    get '/torrent/:id' do
      $mutex.synchronize {
        t = Torrent[:t_id => params[:id]]
        if t then
          @torrent = t
          @x = T.torrents[:all].map do |x| x if x.id == t[:t_id] end.compact.first
          haml :torrent
        end
      }
    end

    get '/hash/:hash' do
      $mutex.synchronize {
        t = Torrent[:t_hash => params[:hash]]
        if t then
          @torrent = t
          haml :hash
        end
      }
    end
    
    get '/completed_torrents.json' do
      $mutex.synchronize {
        @torrents = DB[:torrents]
        x = @torrents.order(:status.asc).map do |torrent|
          torrent
        end
        x.compact.to_json
      }
    end
  
    get '/active_torrents.json' do
      $mutex.synchronize {
        @torrents = DB[:torrents]
        @x = T.torrents[:all] if T.torrents
    
        x = @torrents.order(:status.asc).map do |torrent|
        	if torrent[:status] != "Done" && @x
        		torrent = @x.map do |x| x if x.id == torrent[:t_id] end.compact.first
            if not torrent
              nil
            else
          		[
          		  torrent.id,
          		  torrent.hashString,
          		  torrent.name,
          		  torrent.name[0..20],
          		  @torrents.filter(:t_id => torrent.id).first[:status],
          		  @torrents.filter(:t_id => torrent.id).first[:percent],
          		  pretty_bytes(torrent.totalSize),
          		  pretty_bytes(torrent.downloadedEver),
          		  pretty_bytes(torrent.uploadedEver),
          		  torrent.peersSendingToUs,
          		  torrent.peersGettingFromUs,
          		  (torrent.eta/60),
          		  (torrent.status == 4 ? pretty_bytes(torrent.rateDownload)+"/s" : "--"),
          		  (torrent.status == 4 ? pretty_bytes(torrent.rateUpload)+"/s" : "--"),
          		  ]
      		  end
        	else
        	  nil
          end
        end
        x.compact.to_json
      }
    end
  end
end