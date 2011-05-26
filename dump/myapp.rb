require 'rubygems'
require 'haml'
require 'sequel'
require 'downlow'
require 'fileutils'
require 'mechanize'
require 'sinatra/base'
require 'ninja/threaded'

Ninja.hide_in = Ninja::Threaded.new(4)

class MyApp < Sinatra::Base
  enable :sessions

  set :app_file, __FILE__

  DB = Sequel.sqlite("#{Dir.pwd}/../../dump.db")
  Users = Sequel.sqlite("#{Dir.pwd}/../../../users.db")
  
  DB.create_table? :dumps do
    primary_key :id
    String :filename
    String :code, :index => true, :size => 6
    Integer :downloads, :default => 0
    Time :created_at
  end
  
  Users.create_table? :users do
    primary_key :id
    String :name
    String :email
    String :password
    String :salt
    String :api
    String :sid
    Time :created_at
  end

  class User < Sequel::Model(Users[:users])
  end

  class Dump < Sequel::Model
    include Ninja
    plugin :validation_helpers
    
    def url
      "http://dump.corgasm.org/#{self.code}"
    end

    def get_file(url)
      in_background do
        Downlow::Fetcher.fetch(url, {:destination => "#{Dir.pwd}/../../dump.files/#{self.code}/#{self.filename}"})
      end
    end
    
    def ready?
      File.exists?("#{Dir.pwd}/../../dump.files/#{self.code}/#{self.filename}")
    end
    
    def download
      self.update(:downloads => self.downloads + 1)
      self.save
    end
    
    def newcode
      self.code = (0...6).map{(('a'..'z').to_a+('A'..'Z').to_a+('0'..'9').to_a)[rand(62)]}.join
    end
    
    def validate
      super
      validates_presence :filename
    end
  end
  
  helpers do 
    def logged_in?
      return !!User.filter(:sid => session[:sid]).first
    end
  end
  
  index = lambda do
    if(params[:file]) then
      redirect '/error' if !User.filter(:api => params[:api]).first
      p = Dump.new
      p.filename = params[:file][:filename]
      p.created_at = Time.now
      p.newcode
      tempfile = params[:file][:tempfile]
      FileUtils.mkpath("#{Dir.pwd}/../../dump.files/#{p.code}/")
      FileUtils.copy_file(tempfile.path, "#{Dir.pwd}/../../dump.files/#{p.code}/#{p.filename}")
      if p.valid?
        p.save
        redirect (params[:type] ? "/info/#{p.code}/#{params[:type]}" : "/info/#{p.code}")
      else
        redirect "/error"
      end
    elsif(params[:url]) then
      redirect '/error' if !User.filter(:api => params[:api]).first
      p = Dump.new
      p.filename = Pathname.new(params[:url]).basename
      p.created_at = Time.now
      p.newcode
      FileUtils.mkpath("#{Dir.pwd}/../../dump.files/#{p.code}/")
      p.get_file(params[:url])
      if p.valid?
        p.save
        redirect (params[:type] ? "/info/#{p.code}/#{params[:type]}" : "/info/#{p.code}")
      else
        redirect "/error"
      end      
    else
      @recent = Dump.order(:created_at.desc)
      haml :index
    end
  end
  
  get '*' do
    if params[:sid]
      session[:sid] = params[:sid]
      redirect '/'
    end
    pass
  end
  
  
  get '/', &index
  post '/', &index
  
  get '/error' do
    "Something dun got messed up."
  end
  
  get '/info/:code' do
    if Dump[:code => params[:code]] then
      @url = Dump[:code => params[:code]].url
      haml :show
    end
  end

  get '/info/:code/' do
    if Dump[:code => params[:code]] then
      @url = Dump[:code => params[:code]].url
      haml :show
    end
  end

  get '/info/:code/:type' do
    if Dump[:code => params[:code]] then
      return "{'url': '#{Dump[:code => params[:code]].url}'}" if params[:type] == 'json'
      return "#{Dump[:code => params[:code]].url}" if params[:type] == 'plain'
      return ""
    end
  end
  
  downlol = lambda do
    @file = Dump[:code => params[:code]]
    if @file then
      if @file.ready? then
        content_type File.extname("#{Dir.pwd}/../../dump.files/#{@file.code}/#{@file.filename}").to_sym
        File.read("#{Dir.pwd}/../../dump.files/#{@file.code}/#{@file.filename}")
      else
        "File isn't ready yet."
      end
    else  
      pass
    end
  end

  get '/:code.*', &downlol
  get '/:code/*', &downlol
  get '/:code', &downlol
end