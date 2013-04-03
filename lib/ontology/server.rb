require 'ontology'

require 'json'
#require 'celluloid/autostart'

$channel = EM::Channel.new

class Server < Goliath::WebSocket
  include Goliath::Rack::Templates
  include Celluloid
  #include Celluloid::Notifications

  #use Goliath::Rack::Favicon, File.expand_path(File.dirname(__FILE__) + '/ws/favicon.ico')

  attr_accessor :world_running

  def on_open(env)
    env.logger.info "WS OPEN"

    env['subscription'] = $channel.subscribe do |m|
      env.stream_send(m)
    end

    #unless @world_running
    #  @world_running = true
    #end


    #every(2) do
    #  #World.current.simulate
    #  env.channel << "world is #{World.current.state.value}"
    #end

    # world sub...?
    #subscribe 'topic', 'event'
    #env['world_sub'] = subscribe 'world', :on_event
    #          lambda do |payload|

    #end

  end

  def on_event(payload)
    puts "---- GOT A WORLD MESSAGE WHOA: #{payload.inspect}"
    #env.channel << payload
  end

  def on_message(env, msg)
    env.logger.info "WS MESSAGE: #{msg}"

    p msg
    body = JSON[msg]
    p body
    puts "-- i think the command is #{body['command']}"

    command = body['command']

    return {:error => 201, :message => 'No command given'} unless command

    result = if command == 'chat'
      nickname, message = body['nickname'], body['message']
      if nickname && message
        $channel << "(#{nickname}) #{message}"
        {:ok => 100}
      else
        {:error => 210, :message => "Bad chat command", :detail => "Must provide nickname and message"}
      end
    elsif command == 'world'
      #puts "=== got world command... gonna try talking to that there world process"
      #puts "--- world: #{World.current.state.inspect}"
      #rpc[1] = :b
      #rpc[2] = :c
      #p rpc.keys
      #p rpc.values
      #puts "--- state: #{env.world.state.inspect}"
      {:ok => 100} #:value => World.current.state.value}
    else
      {:error => 202, :message => "Unknown command '#{command}'"}
    end

    #result = case command when 'chat' then
    #           when 'world' then
    #           else
    #         end

    puts "=== returning result: #{result}"
    #result = case body[:command]
    #
    #end
    #env.channel <<
    result
  end

  def on_close(env)
    env.logger.info "WS CLOSED"
    $channel.unsubscribe(env['subscription'])
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

# kick off world simulation... (probably best in a separate process, but for dev anyway...)

# ...also for dev sanity
$stdout.sync = true

World.current.every(0.5) do
  World.current.simulate #(env)
  if World.current.state.value % 10 == 0
    puts "=== you!"
    $channel << 'ohohoh'
  end
end
