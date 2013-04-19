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
  include FirehosePublisher
  DEFAULT_TICK_RATE = 0.064

  attr_accessor :world

  def simulate world, tick_rate=DEFAULT_TICK_RATE
    $world_registry[world.name] = world
    self.world = world
    #World.all.each do |world|

    self.world.game_map.firehose

    #self.world.firehose
    firehose world.reload.snapshot.to_json, world.instance_stream

    # collection manually...?
    firehose(World.all.map(&:snapshot).to_json, "/worlds.json")


    #world = World.get(world_id)
    every tick_rate do
      self.world.step
      #puts "=== world #{world.name} tick #{world.tick} [updates: #{world.updates.count}]"
      # rehydrate client snapshots every 100 ticks
      # will need to send more regular deltas
      #if self.world.tick % 100 == 0
      #  #puts "=== CALLING WORLD SYNC"
      #  #puts "--- world: #{world.inspect}"
      #  #world.save
      #  #world. collection_sync
      #  #world.schedule_update(world.tick+25) do
      #  #  puts "an update!"
      #  #end
      #  #world.reload
      #  world.save!
      #  puts "==== world saved! syncing..."
      #  world.broadcast
        #self.world.firehose
        #firehose world.reload.snapshot.to_json, world.instance_stream
        #
        ## collection manually...?
        #firehose(World.all.map(&:snapshot).to_json, "/worlds.json")
        #
        ##firehose world.snapshot, ""
        #
        ##self.world.collection_sync
        ##world.players.collection_sync
        #if self.world.players.count > 0
        #  puts "=== syncing #{self.world.players.count} world players!"
        #  puts "--- i currently have these players: #{self.world.players.inspect}"
        #  self.world.players.each do |p|
        #    puts "--- firehosing #{p.name}..."
        #    p.firehose
        #  end
        #  firehose(self.world.players.collect(&:snapshot).to_json, "/world/#{world.id}/players.json")
        #  #puts "--- attempting to collection sync via first player: "
        #  #player = self.world.players.first
        #  #puts "--- got player: #{player}"
        #  #player.collection_sync if player
        #end
        #[ self.world.players ].each do |res|
        #  puts "--- got players: #{res.all.map(&:snapshot)}"
        #  res.all.map(&:sync)
        #  res.first.collection_sync if res.count > 0 #res.first
        #  #res.first.collection_sync if res.first
        #end

        #self.world.game_map.sync
        #Player.first.collection_sync
        #self.world.players.map(&:sync)
        #self.world.players.first.collection_sync
        ##self.world.enemies.map(&:sync)
        #self.world.enemies.map(&:sync)
        #self.world.enemies.first.collection_sync
        #
        #self.world.events.map(&:sync)
        #self.world.events.first.collection_sync

      #end
    end
    #end
  end
end

#
#class WorldSnapshotGenerator
#  include Celluloid
#  task_class TaskThread
#  DEFAULT_TICK_RATE = 1.38
#
#  def process tick_rate=DEFAULT_TICK_RATE
#    #puts "--- about to kickoff snapshot maker..."
#    every tick_rate do
#      #puts "==== SNAPSHOT"
#      $world_registry.values.first.collection_sync #snapshot
#      Player.first.collection_sync if Player.first
#
#      Player.all(:fields => [:world_id], :unique => true).each do |p|
#        #puts "--- collection syncing players for world #{p.world.name}"
#        p.collection_sync
#      end
#      Enemy.all(:fields => [:world_id], :unique => true).each do |e|
#        #puts "--- collection syncing enemies for world #{e.world.name}"
#        e.collection_sync
#      end
#      Event.all(:fields => [:world_id], :unique => true).each do |evt|
#        #puts "--- collection syncing events for world #{evt.world.name}"
#        evt.collection_sync
#      end
#    end
#  end
#end

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

# mock player -- just to have a collection to broadcast...
nobody = Player.new({name: "Nobody"})
#nobody.firehose
nobody.firehose [].to_json, "/players.json"
#include FirehosePublisher

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
#puts "--- creating new snapshot generator!"
#WorldSnapshotGenerator.new.process



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
        #player.collection_sync

        player.firehose Player.all.map(&:snapshot).to_json, player.collection_stream
        player.firehose

        puts "--- created player #{player.inspect}!"
        #world.broadcast


      end
      env['player'] = player
      World.all.each { |w| w.broadcast }
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
            world.broadcast
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
          puts "=== attempting to find world #{world_id}"
          world = World.get(world_id) # $world_registry[world_name] #

          #world = Celluloid::Actor[world_name.underscore.to_sym].world
          if world
            puts "--- player #{player} entering world #{world_name}"
            new_position = world.open_positions.sample
            #world.schedule_update(world.tick, {world: world, player: player, position: new_position}) do |opts|
            #  player   = opts[:player]
            #  position = opts[:position]
            #  world    = opts[:world]



              # IDK OK
              world.players << player
              world.players.save!
              world.save!
              #world.sync

              player.x = new_position.x
              player.y = new_position.y

              player.world = world
              player.save!

              puts "--- world players: #{world.players.inspect}"
              world.broadcast
              #world.collection_sync
              env['world'] = world # TODO note that if join fails we'll still have this reference around :/

              puts "=== joined #{world.name}!"
            #end


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
            #puts "=== scheduling move attempt...!"
            #world.schedule_update(world.tick, {player:player, dir:body['direction'], world: world}) do |opts|
            #  world = opts[:world]
            #  direction = opts[:dir]
            #  player = opts[:player]
              world.move(player,body['direction'], body['command_id']) #body['direction'])
            #end
          elsif command == 'leave'
            puts "===== LEAVE"
            # kind of strange; this makes way more sense semiotically as 'player.leave world'
            world.leave(player) if world && player
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
