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

RJR::Dispatcher.add_handler("hello") { |arg|
  puts "=== HELLO"
  arg.upcase
}

RJR::Dispatcher.add_handler("msg") { |arg| #channel,nick,msg|
  puts "=== MSG"
  arg.upcase
  # distribute messages to every client...?
  #Channels.get(channel).message(nick,msg)
}

RJR::Dispatcher.add_handler("world") { |*args|
  puts "=== WORLD"
  args.join(', ')
  # could actually route through em::object::p to the underlying world object (!)
  # (and then on the JS side wrap key methods...)
}

aqmp_node   = RJR::AMQPNode.new :node_id => 'worlds-server', :broker => 'localhost'
ws_node     = RJR::WSNode.new   :node_id => 'worlds-server', :host => 'localhost', :port => 9000
ws_node.listen
ws_node.join


#require 'ontology'
#
#class WorldSocket < Goliath::WebSocket
#  include Goliath::Rack::Templates
#
#  #use Goliath::Rack::Favicon, File.expand_path(File.dirname(__FILE__) + '/ws/favicon.ico')
#
#  def on_open(env)
#    env.logger.info "WS OPEN"
#
#    env['subscription'] = env.channel.subscribe do |m|
#      env.stream_send(m)
#    end
#
#    env.world.each_event do |evt|
#      env.channel.push("<world event>: #{evt}")
#    end
#  end
#
#  def on_message(env, msg)
#    env.logger.info "WS MESSAGE: #{msg}"
#    env.channel << msg
#  end
#
#  def on_close(env)
#    env.logger.info "WS CLOSED"
#    env.channel.unsubscribe(env['subscription'])
#  end
#
#  def on_error(env, error)
#    env.logger.error error
#  end
#
#  def response(env)
#    if env['REQUEST_PATH'] == '/ws'
#      super(env)
#    else
#      [200, {}, erb(:index, :views => Goliath::Application.root_path('views'))]
#    end
#  end
#end
