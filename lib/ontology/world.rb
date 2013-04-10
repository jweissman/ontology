require 'net/http'

require 'data_mapper'
require 'dm-serializer/to_json'
require 'active_support/inflector'

require 'minotaur'

class Fixnum
  def to_json(options = nil)
    to_s
  end
end

CHANNEL = EM::Channel.new

module RemoteActor
  include DataMapper::Resource

  # keep track of remote id? (they're using our keys...)
  property :remote_id, Integer, :key => true

  def model_name
    self.class.name.downcase
  end

  def collection_stream
    "/#{model_name.pluralize}.json"
  end

  def instance_stream
    "/#{model_name}/#{id}.json"
  end

  def snapshot
    attributes
  end

  #class << self
    def collection_sync
      #puts "--- attempting firehose collection sync!"
      puts "--- i have this for the collection: #{self.class.all.inspect}"
      #self.class.all.map(&:snapshot).to_json
      firehose collection_stream, self.class.all.map(&:snapshot).to_json
    end
  #end

  def instance_sync #(payload=snapshot)
    #puts "=== FIREHOSE SYNC WITH PAYLOAD #{payload.inspect}"
    #firehose collection_stream, [payload
    #puts "---- attempting firehose sync :)"
    puts "--- i have this for the current instance: #{snapshot.to_json}"
    firehose instance_stream, snapshot.to_json
  end

  # instance + collection sync (maybe default #sync behavior?)
  def firehose_sync
    puts "=== FIREHOSE BABY"
    instance_sync
    collection_sync
  end


  # TODO i wonder if deletions shouldn't be done out-of-band...

  #def firehose_remove
  #  deletion_message = {id: id, deleted: 'true'}.to_json
  #  firehose_sync(deletion_message)
  #end

  protected
  def firehose(endpoint, payload=to_json)
    # firehose...!
    begin
      puts "--- publishing update to #{endpoint}: #{payload.inspect}"
      req = Net::HTTP::Put.new endpoint #("/#{model_name}/#{id}.json")
      req.body = payload # to_json(:methods => [:players, :game_map]) #, :map])
      Net::HTTP.start('127.0.0.1', 7474).request(req)
    rescue => err
      puts "--- there was a problem talking to firehose :/"
      puts err
    end
  end
  #end
end


class Player # < RemoteActor
  include RemoteActor
  include DataMapper::Resource

  property :id,   Serial
  property :name, String, :default => 'Guest'
  property :x, Integer
  property :y, Integer
  property :last_moved_tick, Integer, :default => 0

  property :status, Enum[ :resting, :moving  ], :default => :resting

  property :speed, Integer, :default => 1 # smaller is faster (less frames between move-throttling)

  validates_uniqueness_of :name

  def position
    Minotaur::Geometry::Position.new(x,y)
  end

  def next_active_tick(current_tick=World.current.tick)
    #puts "=== next active tick? (given current tick #{current_tick})"
    [(last_moved_tick+speed), current_tick].max
  end

  def to_hash
    {
      id:       id,
      name:     name,
      position: [x,y]
    }
  end
end

class GameMap #< RemoteActor
  include RemoteActor
  include DataMapper::Resource

  property :id,    Serial
  property :name,  String

  property :width,   Integer, :default => 5
  property :height,  Integer, :default => 5
  property :rows,    Json,    :default => lambda { |r,p| # r.labyrinth.to_a.to_json } #
                                                         Array.new(r.width) { Array.new(r.height) {0}}.to_json }
    #[[0,0,0,0,0],
    #                                                      [0,0,0,0,0],
    #                                                      [0,0,0,0,0],
    #                                                      [0,0,0,0,0],
    #                                                      [0,0,0,0,0]].to_json } #

  attr_accessor :labyrinth
  def labyrinth
    @labyrinth ||= Minotaur::Labyrinth.new({
      width: @width/2,
      height: @height
    })
  end

  # all stuff from minotaur's grid ... need to make that a module or helpers
  def at(position)
    rows[position.y][position.x]
  end

  def empty?(position)
    at(position).zero?
  end

  def all_positions
    all = []
    Minotaur::Geometry::Grid.each_position(self.width-1,self.height-1) { |pos| all << pos }
    all
  end

  def all_empty_positions
    all_positions.select { |position| empty?(position) }
  end
end

# TODO chat?
class ChatLog
  include RemoteActor
  include DataMapper::Resource
  #include Celluloid

  property :id, Serial
  property :messages, Json, :default => []

  def message(speaker,payload)
    messages << [Time.now,speaker,payload]
  end
end

class World #< RemoteActor
  include RemoteActor
  include DataMapper::Resource
  include Minotaur::Geometry::Directions


  # TODO hook into backbone collection/instance (i.e., round-trip from datamapper)
  # don't seem to be getting called? or maybe i'm missing something
  #after :create, :firehose_sync
  #before :save, :firehose_sync

  DIRECTIONS = {n: NORTH, e: EAST, s: SOUTH, w: WEST}

  has 1, :chat_log
  has 1, :game_map
  has n, :players

  property :id,   String, :key => true
  property :name, String, :default => 'datamapper default name'

  property :tick, Integer, :default => 0

  def self.construct(name="New World")
    world = World.create({id: SecureRandom.uuid, name: name, game_map: GameMap.create(name: 'manually assigned name on server!')})
    #WorldSimulator.new(world).simulate
    world
  end

  def open_positions
    game_map.all_empty_positions - players.all(&:positions)
  end

  def scheduled_updates
    @scheduled_updates ||= []
  end

  def schedule_update(t=@tick,opts={},&block)
    puts "--- scheduling update at t=#{t}..."
    @scheduled_updates << [t,opts,block] if block_given?
  end

  def join(player)
    puts "--- #{player.name} joins the realm!*******************"
    new_position = open_positions.sample
    puts "=== player attempting to be placed at #{new_position}"
    puts "--- #{new_position.inspect}"
    player.update({x:new_position.x,y:new_position.y})
    players << player
    player.save!
    save!
    puts "--- everything saved...!"
  end

  def leave(player)
    player.world = nil
    player.save
    puts "--- player should no longer be in world...!"
  end

  def active_player_ids
    players.map(:id)
  end

  COMPASS = {:n => NORTH, :e => EAST, :w => WEST, :s => SOUTH}
  def move(player, direction)
    if player.status == :moving
      puts "=== PLAYER IS ALREADY MOVING, IGNORING MOVE COMMAND"
      return
    end

    puts "--- Player attempting to move!"


    x, y = player.x, player.y
    direction = direction.slice(0,1).downcase.to_sym

    if COMPASS.has_key?(direction)
      puts "--- I've got player #{player.name} at position #{x}, #{y} attempting to move in valid direction #{direction}..."
      dir = COMPASS[direction]
      target = Minotaur::Geometry::Position.new(DX[dir]+x, DY[dir]+y)
      open = open_positions.include?(target)
      #puts game_map.rows.inspect
      puts "--- Is that position open? #{open}"
      return false unless open
      puts "=== It seems okay! Setting player's status to moving..."
      player.status = :moving
      player.save
      puts "--- And scheduling move!!!"
      schedule_update(player.next_active_tick, {target: target, player: player}) do |opts|

        target = opts[:target]
        player = opts[:player]
        puts "=== ACTUALLY PERFORMING MOVE OF PLAYER #{player.name} TO TARGET POSITION #{target}"
        puts "--- all players before update: #{players.all.map(&:to_hash)}"
        puts "--- player before update: #{player.inspect}"
        player.x = target.x
        player.y = target.y
        player.status = :resting
        player.save
        puts "--- all players before update: #{players.all.map(&:to_hash)}"
        puts "--- player after update: #{player.inspect}"
        #broadcast_snapshot
      end
      true
    else
      false
    end
  end

  # tick! is expecting to be called every 65ms or so
  def step
    #puts "--- world #@name (#@id) step!!!!!"
    if self.tick
      self.tick += 1
      updates_to_remove = []
      scheduled_updates.each_with_index do |(t,opts,update_block),n|
        if t <= self.tick
          puts "--- running scheduled update!"
          update_block.call(opts)
          updates_to_remove << n
        end
      end
      updates_to_remove.each { |n| @scheduled_updates.delete_at(n) }
    end
  end

  def chat(*args)
    puts "=== CHAT NOT IMPLEMENTED YET GO AWWAY"
  end

  def snapshot
    # TODO handle map by reference too...?
    attributes.merge(players: players.map(&:id), map: game_map.rows)
  end
end


class WorldSimulator
  include Celluloid
  task_class TaskThread

  def simulate
    World.all.each do |world|
      every(0.66) do
        world.step

        # update client snapshots every 5 ticks
        if world.tick % 5 == 0
          world.save
          world.firehose_sync
        end
      end
    end
  end
end


## setup dm #####
DataMapper.finalize
DataMapper::Logger.new($stdout, :debug)
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
  3.times do |n|
    World.construct("World #{n}").save
  end
end

puts "--- world count: #{World.count}"
puts "--- starting simulator!"
WorldSimulator.new.simulate
