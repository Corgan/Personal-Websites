require 'rubygems'
require 'haml'
require 'grit'
require 'sequel'
require 'sinatra/base'

class MyApp < Sinatra::Base
  include Grit
  set :app_file, __FILE__

  DB = Sequel.sqlite("#{Dir.pwd}/../../git.db")

  get '/favicon.ico' do
    ""
  end

  get '/' do
    @repos = Dir['../*'].map do |x|
      Repo.new("#{Dir.pwd}/#{x}")
    end
    haml :index
  end
  
  repo = lambda do
    @repo = Repo.new("#{Dir.pwd}/../#{params[:repo]}")
    @repo_name = (@repo.path.split('/')[-1] == '.git' ? @repo.path.split('/')[-2] : @repo.path.split('/')[-1])
    @commits = @repo.commits('master', 999)
    haml :repo
  end
  
  action = lambda do
    @repo = Repo.new("#{Dir.pwd}/../#{params[:repo]}")
    @repo_name = (@repo.path.split('/')[-1] == '.git' ? @repo.path.split('/')[-2] : @repo.path.split('/')[-1])
    @commit = @repo.commit((params[:commit] ? params[:commit] : 'HEAD'))
    haml params[:action].to_sym
  end
    
  get '/:repo', &repo
  get '/:repo/', &repo
  get '/:repo/:action', &action
  get '/:repo/:action/', &action
  get '/:repo/:action/:commit', &action
  get '/:repo/:action/:commit/', &action
end
