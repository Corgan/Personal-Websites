require 'rubygems'
require 'haml'
require 'sequel'
require 'sinatra/base'

class MyApp < Sinatra::Base
  enable :sessions
  set :app_file, __FILE__

  Users = Sequel.sqlite("#{Dir.pwd}/../../../users.db")
  
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
    plugin :validation_helpers
    def pass=(pass)
      self.salt = (0...8).map{(('a'..'z').to_a+('A'..'Z').to_a)[rand(52)]}.join
      self.password = User.encrypt(pass, self.salt)
    end
    
    def key
      self.api = (0...20).map{(('a'..'z').to_a+('A'..'Z').to_a)[rand(52)]}.join
      self.save
    end

    def self.encrypt(pass, salt)
      Digest::SHA1.hexdigest(pass + salt)
    end

    def self.authenticate(name, pass)
      u = User.first(:name => name)
      return nil if u.nil?
      if User.encrypt(pass, u.salt) == u.password
        u.sid = (0...20).map{(('a'..'z').to_a+('A'..'Z').to_a)[rand(52)]}.join
        u.save
        return u
      end
      nil
    end
    
    def validate
      super
      validates_presence [:name, :email]
      validates_unique :name
    end
  end
  
  helpers do
    def logged_in?
      return true if session[:user]
      nil
    end
  end

  get '/' do
    haml :index
  end
  
  get '/login' do
    if logged_in?
      if params[:ref]
        redirect "#{params[:ref]}/?sid=#{session[:user].sid}"
      else
        redirect "/"
      end
    else
      haml :login
    end
  end

  post '/login' do
    if session[:user] = User.authenticate(params[:name], params[:password])
      if params[:ref]
        redirect "#{params[:ref]}/?sid=#{session[:user].sid}"
      end
      redirect '/'
    else
      redirect '/login'
    end
  end

  get '/logout' do
    u = User[:id => session[:user].id]
    u.sid = nil
    u.save
    session[:user] = nil
    redirect '/'
  end

  get '/create' do
    haml :create
  end

  post '/create' do
    u = User.new
    u.name = params[:name]
    u.pass = params[:password]
    u.email = params[:email]
    if u.valid?
      u.created_at = Time.now
      u.key
      session[:user] = User.authenticate(params[:name], params[:password])
      redirect '/'
    else
      redirect '/create'
    end
  end
  
  get '/api' do
    if logged_in?
      haml "#{session[:user].api}"
    else
      redirect '/login'
    end
  end

  get '/regen' do
    if logged_in?
      User[:id => session[:user].id].key
      session[:user] = User[:id => session[:user].id]
      redirect '/api'
    else
      redirect '/login'
    end
  end
end
