require 'ontology'

require 'json'
require 'celluloid'

CHANNEL = EM::Channel.new

class Server < Goliath::WebSocket
  include Goliath::Rack::Templates

  def channel; CHANNEL end

  #attr_accessor :world_running

  def on_open(env)
    env.logger.info "WS OPEN"

    #env['player_id'] = SecureRandom.uuid
    env['subscription'] = channel.subscribe do |m|
      env.stream_send(m)
    end
  end

  def on_message(env, msg)
    env.logger.info "WS MESSAGE: #{msg} [PLAYER_ID #{env['player_id']}]"

    # i keep thinking that it might be better to deref based on some secure header...
    #env['goliath.request-headers'].each_pair do |key, value|
    #  puts ">>> #{key} => #{value}"
    #end

    body = JSON[msg]
    command, player_name = body['command'], body['user']

    return unless command && player_name
    env.logger.debug "--- command: #{command}"
    env.logger.debug "--- player: #{player_name}"

    result = { :command => command, :status => 200, :player => player_name, :player_id => env['player_id'] }
    if command == 'join'
      World.current.join(player_name)
      #env['player_id'] = player.id

      result[:players] = World.current.players.map do |player|
        #env.logger.debug player.inspect
        {
          id:             player.id,
          name:           player.name,
          position:       player.position
        }
      end
      result[:map] = World.current.game_map.rows
    #elsif command == 'bye'
    #  World.current.remove_player(name)
    else
      player = Player.all(name: player_name).first
      return unless player

      if command == 'chat'
        result[:message] = body['message']
      elsif command == 'move'
        direction = body['direction']
        env.logger.debug "--- okay! "
        moved = World.current.move(player, direction)
        result[:position] = player.position if moved
      # TODO elsif command == 'use'

      end
    end

    env.logger.info "=== returning result: #{result}"
    channel << result.to_json
  end

  def on_close(env)
    env.logger.info "WS CLOSED"
    channel.unsubscribe(env['subscription'])
    # TODO remove players from world!
    # World.current.remove_player(env['player_id']) or something
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
