require 'rubygems'
require 'haml'
require 'json'
require 'sequel'
require 'sinatra/base'

class MyApp < Sinatra::Base
  set :app_file, __FILE__

  DB = Sequel.sqlite("#{Dir.pwd}/../../urls.db")
  Users = Sequel.sqlite("#{Dir.pwd}/../../../users.db")
  
  DB.create_table? :urls do
    primary_key :id
    String :long_url, :index => true, :size => 255
    String :code, :index => true, :size => 6
    Integer :visits, :default => 0
    Time :created_at
  end

  class Url < Sequel::Model
    VALID_URL_REGEX = /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$/ix
    def validate
      super
      errors.add(:long_url, 'is not valid') if !long_url.match(VALID_URL_REGEX)
    end
    
    def visit
      self.update(:visits => self.visits + 1)
      self.save
    end
    
    def short_url
      "http://s.corgasm.org/#{self.code}"
    end
    
    def url=(url)
      self.long_url = url
      self.code = (0...6).map{(('a'..'z').to_a+('A'..'Z').to_a+('0'..'9').to_a)[rand(62)]}.join
    end
    
  end

  helpers do    
    def normalize(url)
      URI.parse(url).normalize.to_s
    end
  end
  
  get '/' do
    @urls = Url.all
    haml :index
  end
  
  add = lambda do
    long_url = normalize(params[:url])
    u = Url.new
    u.url = long_url
    if u.valid?
      u.save
      redirect (params[:type] ? "/info/#{u.code}/#{params[:type]}" : "/info/#{u.code}")
    else
      redirect "/error"
    end
  end
  
  get '/add', &add
  
  post '/add', &add
  
  get '/error' do
    "Something dun got messed up."
  end
  
  get '/info/:code' do
    if Url[:code => params[:code]] then
      @url = Url[:code => params[:code]]
      haml :show
    end
  end

  get '/info/:code/:type' do
    if Url[:code => params[:code]] then
      
      return {:url => Url[:code => params[:code]].short_url}.to_json if params[:type] == 'json'
      return "#{Url[:code => params[:code]].short_url}" if params[:type] == 'plain'
      return ""
    end
  end
  
  get '/:code' do
    u = Url[:code => params[:code]]
    if u then
      u.visit
      redirect u[:long_url], 301
    end
  end

end