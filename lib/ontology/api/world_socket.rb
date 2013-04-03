#class Channel
#  def clients
#    @clients ||= []
#  end
#
#  def subscribe(client)
#    # ...
#    clients << client
#  end
#
#  def message(nickname,body)
#    # push message to clients?
#    clients.each do |client|
#
#    end
#  end
#end


# Ontology::API::AsyncWorldClient.new
#
#RJR::Dispatcher.add_handler("hello") { |arg|
#  puts "=== HELLO"
#  arg.upcase
#}
#
#RJR::Dispatcher.add_handler("msg") { |arg| #channel,nick,msg|
#  puts "=== MSG"
#  arg.upcase
#  # distribute messages to every client...?
#  #Channels.get(channel).message(nick,msg)
#}
#
#RJR::Dispatcher.add_handler("world") { |*args|
#  puts "=== WORLD"
#  args.join(', ')
#  # could actually route through em::object::p to the underlying world object (!)
#  # (and then on the JS side wrap key methods...)
#}
#
#aqmp_node   = RJR::AMQPNode.new :node_id => 'worlds-server', :broker => 'localhost'
#ws_node     = RJR::WSNode.new   :node_id => 'worlds-server', :host => 'localhost', :port => 9000
#ws_node.listen
#ws_node.join

require 'goliath'
require 'goliath/websocket'
require 'ontology'

class WorldSocket < Goliath::WebSocket
  include Goliath::Rack::Templates

  #use Goliath::Rack::Favicon, File.expand_path(File.dirname(__FILE__) + '/ws/favicon.ico')

  def on_open(env)
    env.logger.info "WS OPEN"

    env['subscription'] = env.channel.subscribe do |m|
      env.stream_send(m)
    end
  end

  def on_message(env, msg)
    env.logger.info "WS MESSAGE: #{msg}"

    p msg
    body = JSON[msg]
    p body
    puts "-- i think the command is #{body['command']}"

    command = body['command']

    return {:error => 201, :message => 'No command given'} unless command

    result = case command when 'chat' then
      nickname, message = body['nickname'], body['message']
      if nickname && message
        env.channel << "(#{nickname}) #{message}"
        {:ok => 100}
      else
        {:error => 210, :message => "Bad chat command", :detail => "Must provide nickname and message"}
      end
    when 'world' then
      puts "=== got world command... gonna try talking to that there world process"
      puts "--- rpc: #{env.rpc.inspect}"
      rpc[1] = :b
      rpc[2] = :c
      p rpc.keys
      p rpc.values
      #puts "--- state: #{env.world.state.inspect}"
      {:ok => 100}
    else
      {:error => 202, :message => "Unknown command '#{command}'"}
    end

    puts "=== returning result: #{result}"
    #result = case body[:command]
    #
    #end

    #env.channel <<
    result.to_json
  end

  def on_close(env)
    env.logger.info "WS CLOSED"
    env.channel.unsubscribe(env['subscription'])
  end

  def on_error(env, error)
    env.logger.error error
  end

  def response(env)
    if env['REQUEST_PATH'] == '/ws'
      super(env)
    else
      [200, {}, erb(:index, :views => Goliath::Application.root_path('views'))]
    end
  end
end
