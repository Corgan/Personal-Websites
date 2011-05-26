require 'rubygems'
require 'haml'
require 'sequel'
require 'sinatra/base'
require 'isaac/bot'
require 'ninja/threaded'

class Isaac::Bot
  def connect
    tcp_socket = TCPSocket.open(@config.server, @config.port)

    if @config.ssl
      begin
        require 'openssl'
      rescue ::LoadError
        raise(RuntimeError,"unable to require 'openssl'",caller)
      end

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

      unless @config.environment == :test
        puts "Using SSL with #{@config.server}:#{@config.port}"
      end

      @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
      @socket.sync = true
      @socket.connect
    else
      @socket = tcp_socket
    end

    @queue = Queue.new(@socket, @bot.config.server)
    message "PASS #{@config.password}" if @config.password
    message "NICK #{@config.nick}"
    message "USER #{@config.user} 0 * :#{@config.realname}"
    @queue.lock

    while line = @socket.gets
      parse line
    end
  end
end

Ninja.hide_in = Ninja::Threaded.new(4)
$msgs = []
class MyApp < Sinatra::Base
  set :app_file, __FILE__
  
  class IRCBot
    include Ninja
    def initialize
      @bot = Isaac::Bot.new do
      	configure do |c|
      	  c.nick    = "Corgasm"
      	  c.server  = "irc.corgasm.org"
      	  c.port    = 2200
      	  c.password = "testinglol"
      	end
      	on :channel do
      	  $msgs << [nick, channel, message]
      	  $msgs.delete_at(0) if $msgs.length > 5
      	end
      end
    end
    def run
      in_background do
        @bot.start
      end
    end
  end

  bot = IRCBot.new
  bot.run
  DB = Sequel.sqlite("#{Dir.pwd}/../../webirc.db")

  get '/' do
    haml :index
  end
  
  get '/lines.json' do
    $msgs.inspect
  end
end
