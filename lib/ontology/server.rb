require 'ontology'

require 'json'
require 'celluloid'

#class Command
#end

class Server < Goliath::WebSocket
  include Goliath::Rack::Templates

  # hmmm
  def channel; CHANNEL end

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
    player_id    = body['player_id']
    player_name  = body['player_name']
    return unless command && player_id && player_name

    env.logger.debug "--- command:  #{command}"
    env.logger.debug "--- player:   #{player_name} (#{player_id})"
    if command == 'ping'

      puts "=== PING (add player) from #{player_name} (#{player_id})"
      # TODO seems to be broken??
      player = Player.get(player_id) #{id: player_id, name: player_name})
      if player
        puts "--- player already exists! hello #{player.name}!"
      else
        puts "--- creating player"
        player = Player.create({id:player_id,name:player_name})
        player.save!
        puts "--- created player!"
        puts "--- here's the list of all players if you're curious: "
        puts Player.all.inspect

      end
    else
      puts "--- looking up player entity based on id #{player_id}..."
      player = Player.get(player_id)
      if player
        puts "--- player #{player.name} found!"

        # TODO create worlds..
        #if command == 'create'
        #  # create a new world!
        #  puts "--- got a create world '#{world_name}' command!"
        #  world_name = body['world_name']
        #  world = World.create({name: world_name})
        #  if world.valid?
        #    puts "--- world is valid, saving!"
        #    world.save
        #    puts "--- spinning up new world #{world_name}!"
        #    spin_up world
        #    puts "=== okay, new world #{world_name} has hopefully been spun up..."
        #  else
        #    puts "--- world #{world_name} was not valid"
        #  end
        if command == "join"
          puts "--- handling join...********************************"

          world_id = body['world_id']
          world = World.get(world_id)

          puts "--- player #{player.name} joining world #{world.name}"
          world.join(player)
        else
          # so at this point we know the player and the world
          world = player.world
          puts "--- player #{name} is in world #{world.name}"
          if command == 'chat'
            world.chat(player,body['message'])
          elsif command == 'move'
            world.move(player,body['direction'])
          elsif command == 'leave'
            world.leave(player)
          else
            puts "--- got unknown command #{command}"
          end
        end
      else
        puts "====== no player with id #{player_id} found :("
      end
    end
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
