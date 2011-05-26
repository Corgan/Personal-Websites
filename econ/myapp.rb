require 'rubygems'
require 'haml'
require 'sequel'
require 'cgi'
require 'downlow'
require 'sinatra/base'
require 'sinatra/memcache'

class MyApp < Sinatra::Base
  register Sinatra::MemCache
  
  enable :sessions
  
  set :app_file, __FILE__
  set :environment, :development
  
  set :cache_server, "localhost:11211"
  set :cache_namespace, "sinatra-memcache"
  set :cache_enable, true
  set :cache_logging, true
  set :cache_default_expiry, 300
  set :cache_default_compress, true

  DB = Sequel.sqlite("#{Dir.pwd}/../../econ.db")
  FACTION = ["Alliance", "Horde", "Neutral"]

  class Money
  attr_reader :total
  alias_method :to_i, :total
  def initialize(total)
    @total = total.to_i
  end
  def to_s
    tmp = []
    tmp << "<span class='moneygold'>#{gold}</span>" if gold > 0
    tmp << "<span class='moneysilver'>#{silver}</span>" if silver > 0
    tmp << "<span class='moneycopper'>#{copper}</span>" if copper > 0
    return tmp.join(" ")
  end
  def gold
    return (@total / 10000)
  end
  def silver
    return (@total % 10000) / 100
  end
  def copper
    return @total % 100
  end
end

  class Item < Sequel::Model
  end
  class Auction < Sequel::Model
  end
  class Server < Sequel::Model
  end
  class Character < Sequel::Model
  end

  helpers do
  end
  
  get '/' do
    cache "/" + params.map { |k,v| "#{k}=#{v}" }.join("&") do
      if params[:r] && params[:c] then
        table  = Auction
        search = {:server => params[:r], :seller => params[:c]}
        order  = :buyout.desc
        limit  = 100
        page   = :item
      elsif params[:r] && params[:f] then
        table  = Auction
        search = {:server => params[:r], :faction => params[:f]}
        order  = :buyout.desc
        limit  = 100
        page   = :item
      elsif params[:f] then
        table  = Auction
        search = {:faction => params[:f]}
        order  = :buyout.desc
        limit  = 100
        page   = :item
      elsif params[:i] then
        table  = Auction
        search = {:id => params[:i]}
        order  = :buyout.desc
        page   = :item
      elsif params[:s] then
        table  = Auction
        search = :name.like("%#{params[:s]}%")
        order  = :buyout.desc
        page   = :item
        limit = 100
      else
        table  = Server
        page   = :index
      end
  
      @results = table
      @results = @results.filter(search) if search
      @results = @results.order(order)   if order
      @results = @results.limit(limit)   if limit
      haml page
    end
  end

  get '/test' do
    cache 'test' do
      @results = Item
      @results = @results.order(:qual.desc, :name.asc).all
      haml :test
    end
  end

  get '/expire' do
    haml "Expired: <br />" + expire(//).join("<br />")
  end
  
  get '/icons/small/:icon.jpg' do
    if File.exists?("#{Dir.pwd}/icons/#{params[:icon]}.jpg") then
      content_type File.extname("#{Dir.pwd}/icons/#{params[:icon]}.jpg").to_sym
      File.read("#{Dir.pwd}/icons/#{params[:icon]}.jpg")
    else
      Downlow::Fetcher.fetch("http://static.wowhead.com/images/wow/icons/small/#{params[:icon]}.jpg", {:destination => "#{Dir.pwd}/icons/#{params[:icon]}.jpg"})
        content_type File.extname("#{Dir.pwd}/icons/#{params[:icon]}.jpg").to_sym
      File.read("#{Dir.pwd}/icons/#{params[:icon]}.jpg")
    end
  end
  
  get '/*' do
    halt 404, {'Content-Type' => 'text/plain'}, 'BAD'
  end

end