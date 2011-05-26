require 'rubygems'
require 'haml'
require 'sequel'
require 'htmlentities'
require 'cgi'
require 'coderay'
require 'sinatra/base'

class MyApp < Sinatra::Base
  set :app_file, __FILE__

  DB = Sequel.sqlite("#{Dir.pwd}/../../code.db")
  Users = Sequel.sqlite("#{Dir.pwd}/../../../users.db")
  
  DB.create_table? :pasties do
    primary_key :id
    String :body
    String :code, :index => true, :size => 6
    Integer :visits, :default => 0
    Time :created_at
  end

  class Pastie < Sequel::Model
    plugin :validation_helpers
    def visit
      self.update(:visits => self.visits + 1)
      self.save
    end    
    def newcode
      self.code = (0...6).map{(('a'..'z').to_a+('A'..'Z').to_a+('0'..'9').to_a)[rand(62)]}.join
    end
    def validate
      super
      validates_presence :body
    end
  end
  
  helpers do
    def display(body)
      CodeRay.scan(body, :ruby).span(:css => :class)
    end
  end

  get '/' do
    @pasties = Pastie.all
    haml :index
  end
  
  get '/new' do
    haml :new
  end
  
  post '/new' do
    body = params[:body]
    p = Pastie.new
    p.body = body
    p.created_at = Time.now
    p.newcode
    if p.valid?
      p.save
      redirect "/#{p.code}"
    else
      redirect "/error"
    end
  end
  
  
  get '/error' do
    "Something dun got messed up."
  end
  
  get '/:code' do
    @pastie = Pastie[:code => params[:code]]
    if @pastie then
      @pastie.visit
      haml :show
    end
  end

end