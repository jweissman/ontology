require 'ontology'

require 'json'
require 'celluloid'

#class Command
#end

#### figure out how to break this apart...


$world_registry = {}
# todo needs to be started with a supervisor so we can shut it down :)
class WorldSimulator# < Struct.new(:world_id)
  include Celluloid
  task_class TaskThread
  DEFAULT_TICK_RATE = 0.066


  attr_accessor :world

  def simulate world, tick_rate=DEFAULT_TICK_RATE
    $world_registry[world.name] = world
    @world = world
    #World.all.each do |world|

    #world = World.get(world_id)
    every tick_rate do

      self.world.step
      puts "=== world #{world.name} tick #{world.tick} [updates: #{world.updates.count}]"
      # update client snapshots every 5 ticks
      #if self.world.tick % 10 == 0
        #puts "=== CALLING WORLD SYNC"
        #puts "--- world: #{world.inspect}"
        #world.save
        #world. collection_sync
        #world.schedule_update(world.tick+25) do
        #  puts "an update!"
        #end
        #world.reload
        self.world.save
        self.world.sync
        self.world.game_map.sync
        self.world.players.map(&:sync)
        self.world.enemies.map(&:sync)

      #end
    end
    #end
  end
end


class WorldSnapshotGenerator
  include Celluloid
  task_class TaskThread
  DEFAULT_TICK_RATE = 0.22

  def process tick_rate=DEFAULT_TICK_RATE
    #puts "--- about to kickoff snapshot maker..."
    every tick_rate do
      #puts "==== SNAPSHOT"
      $world_registry.values.first.collection_sync #snapshot
      Player.first.collection_sync if Player.first

      Player.all(:fields => [:world_id], :unique => true).each do |p|
        #puts "--- collection syncing players for world #{p.world.name}"
        p.collection_sync
      end
      Enemy.all(:fields => [:world_id], :unique => true).each do |e|
        #puts "--- collection syncing enemies for world #{e.world.name}"
        e.collection_sync
      end
      Event.all(:fields => [:world_id], :unique => true).each do |evt|
        #puts "--- collection syncing events for world #{evt.world.name}"
        evt.collection_sync
      end
    end
  end
end

# could move to 'runner'...?

## setup dm #####


DataMapper.finalize
DataMapper::Logger.new($stdout, :info)
DataMapper.setup :default, "sqlite://#{Dir.pwd}/world.db"
DataMapper.auto_migrate!

$stdout.sync = true

## kick off simulation ####

## TODO this is a whole world of problems :/ figure out a better way to supervise this...
##      probably magnified by the multiple worlds (i.e., if one crashes...)
##      though the multiple worlds points to a possible solution -- a supervisor that monitors them all,
##      attempts to reboot them -- i.e., like an adult might actually use celluloid

puts "=== kicking off simulation!"

if World.count == 0
  puts "--- building a few worlds to start us off..."
  1.times do |n|
    world = World.create(name: "Sandbox #{n}").save!
    #puts "--- created world: #{world.inspect}"
  end
  puts "--- done building worlds...."
end

puts "--- world count: #{World.count}"
puts "--- starting simulator!"
World.all.each do |world|
  puts "--- simulating world #{world.name}"
  WorldSimulator.new.simulate(world)
end
#
puts "--- creating new snapshot generator!"
WorldSnapshotGenerator.new.process



### CORE API SERVER
# what is all that other junk :)

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
      #env['player'] = player
      player = Player.get(player_id) #{id: player_id, name: player_name})
      if player
        puts "--- player already exists, hello #{player.name}!"
      else
        player = Player.new({id:player_id,name:player_name})
        player.save!
        puts "--- created player #{player.inspect}"
      end
      env['player'] = player

    else
      # yeah, see we could just be using env['player'] i think
      # (i.e., and not need to pass player_id in)
      puts "--- looking up player entity based on id #{player_id}..."
      player = Player.get(player_id)
      if player
        puts "--- player #{player.name} found!"

        # TODO create worlds..
        if command == 'create'
          # create a new world!
          world_name = body['world_name']
          return unless world_name
          puts "=== attempting to create world #{world_name}!"
          world = World.create({name: world_name})
          if world.valid?
            puts "--- world is valid, saving!"
            world.save
            puts "--- spinning up new world #{world_name}!"
            #spin_up world
            WorldSimulator.new.simulate(world)
            puts "=== okay, new world #{world_name} has hopefully been spun up...!"
          else
            puts "--- world #{world_name} was not valid"
            puts world.errors
          end
        elsif command == "join"
          puts "----- handling join for player.."
          puts "--- #{player.inspect}"
          #if player

          # hmmmm.... :/
          world_id = body['world_id']
          world = World.get(world_id)
          #world = Celluloid::Actor[world_name.underscore.to_sym].world
          if world
            new_position = world.open_positions.sample
            player.x = new_position.x
            player.y = new_position.y
            player.world = world
            player.save!

            # IDK OK
            world.players << player
            world.save

            env['world'] = world
            puts "=== joined #{world.name}!"
          else
            puts "--- would join but world is not valid...? :("
          end
        else
          # so at this point we know the player and the world
          #puts "=== we should know the player and the world at this point"
          world = $world_registry[env['world'].name] # env['world'] #World.get(player.world.id)
          #puts "--- got world:"
          #puts "=== env world: #{env['world']}"
          ##world_id = body['world_id']
          #world_name = World.get(world_id).name

          #world = Celluloid::Actor[player.world.name.underscore.to_sym].world
          puts "--- player #{player.name} is in world #{world.name}"
          if command == 'chat'
            world.chat(player,body['message'])
          elsif command == 'move'
            world.move(player,body['direction'])
          elsif command == 'leave'
            puts "===== LEAVE"
            # kind of strange; this makes way more sense semiotically as 'player.leave world'
            world.leave player
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

    # TODO remove players from world! (maybe addressed)?
    env['world'].leave(env['player'])
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
