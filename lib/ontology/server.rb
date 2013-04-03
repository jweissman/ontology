require 'ontology'
require 'json'

CHANNEL = EM::Channel.new

class Server < Goliath::WebSocket
  include Goliath::Rack::Templates
  include Celluloid

  def channel; CHANNEL end

  attr_accessor :world_running

  def on_open(env)
    env.logger.info "WS OPEN"

    env['subscription'] = channel.subscribe do |m|
      env.stream_send(m)
    end
  end

  def on_message(env, msg)
    env.logger.info "WS MESSAGE: #{msg}"

    #env['goliath.request-headers'].each_pair do |key, value|
    #  puts ">>> #{key} => #{value}"
    #end
    body = JSON[msg]
    command = body['command']

    return unless command
                        
    #player_name = body['name']
    if command == 'chat'
      name, message = body['name'], body['message']
      #channel << "(#{name}) #{message}" if name && message
      channel << {:command => 'chat', :name => name, :message => message}.to_json if name && message
    elsif command == 'join'
      name = body['name']
      World.current.async.add_player(name)
      channel << { :command => 'players', :players => World.current.players.map(&:name) }.to_json
    end
  end

  def on_close(env)
    env.logger.info "WS CLOSED"
    channel.unsubscribe(env['subscription'])
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

$stdout.sync = true

# kick off world simulation... (probably best in a separate process, but for now anyway...)
World.current.every(0.5) do
  World.current.simulate #(env)
#  if World.current.state.value % 10 == 0
#    CHANNEL << '...'
#  end
end
