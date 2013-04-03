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

    body = JSON[msg]
    command = body['command']

    return {:error => 201, :message => 'No command given'} unless command

    result = if command == 'chat'
      nickname, message = body['nickname'], body['message']
      if nickname && message
        channel << "(#{nickname}) #{message}"
        {:ok => 100}
      else
        {:error => 210, :message => "Bad chat command", :detail => "Must provide nickname and message"}
      end
    elsif command == 'world'
      {:ok => 100, :value => World.current.state.value}
    else
      {:error => 202, :message => "Unknown command '#{command}'"}
    end
    result
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
  if World.current.state.value % 10 == 0
    CHANNEL << '...'
  end
end
