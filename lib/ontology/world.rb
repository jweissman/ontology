require 'data_mapper'
require 'dm-serializer/to_json'
require 'minotaur'

CHANNEL = EM::Channel.new

class Fixnum
  def to_json(options = nil)
    to_s
  end
end

class Player
  include DataMapper::Resource

  property :id,   Serial
  property :name, String, :default => 'Guest'
  property :x, Integer
  property :y, Integer
  property :last_moved_tick, Integer, :default => 0

  property :status, Enum[ :resting, :moving, :fighting, :tired, :sick, :injured, :dead ], :default => :resting

  property :speed, Integer, :default => 14 # smaller is faster (less frames between move-throttling)

  validates_uniqueness_of :name

  def position
    Minotaur::Geometry::Position.new(x,y)
  end

  def next_active_tick(current_tick=World.current.tick)
    puts "=== next active tick? (given current tick #{current_tick})"
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

class GameMap
  include DataMapper::Resource

  property :id,    Serial
  property :name,  String

  property :width,   Integer, :default => 5
  property :height,  Integer, :default => 5
  property :rows,    Json,    :default => lambda { |r,p| [[1,1,1,1,1],
                                                          [1,0,0,0,1],
                                                          [1,0,0,0,1],
                                                          [1,0,0,0,1],
                                                          [1,1,1,1,1]].to_json } # r.labyrinth.to_a.to_json }

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
    Minotaur::Geometry::Grid.each_position(self.width,self.height) { |pos| all << pos }
    all
  end

  def all_empty_positions
    all_positions.select { |position| empty?(position) }
  end
end

class World
  include DataMapper::Resource
  include Celluloid
  include Minotaur::Geometry::Directions

  DIRECTIONS = {n: NORTH, e: EAST, s: SOUTH, w: WEST}

  has 1, :game_map
  has n, :players

  property :id,  Serial
  property :name, String

  property :tick, Integer, :default => 0

  task_class TaskThread

  def self.current
    @@current ||= construct
  end

  def self.construct
     World.create({name: 'Hello', game_map: GameMap.create(name: 'Worlddds!')})
  end

  def open_positions
    game_map.all_empty_positions - players.all(&:positions)
  end

  def scheduled_updates
    @scheduled_updates ||= []
  end

  def schedule_update(t,opts={},&block)
    puts "--- scheduling update..."
    @scheduled_updates << [t,opts,block] if block_given?
  end

  def join(player_name)
    puts "--- join!"
    new_position = open_positions.sample
    puts "=== player attempting to be placed at #{new_position}"
    puts "--- #{new_position.inspect}"
    players << Player.create({name:player_name,x:new_position.x,y:new_position.y})
  end

  COMPASS = {:n => NORTH, :e => EAST, :w => WEST, :s => SOUTH}
  def move(player, direction)
    return if player.status == :moving
    puts "=== move #{player} #{direction}!"
    x, y = player.x, player.y
    puts "--- to #{x}, #{y}"
    direction = direction.slice(0,1).downcase.to_sym
    puts "--- direction #{direction}, checking compass"
    if COMPASS.has_key?(direction)
      dir = COMPASS[direction]
      target = Minotaur::Geometry::Position.new(DX[dir]+x, DY[dir]+y)
      puts "--- target position is #{target}"
      open = open_positions.include?(target)
      puts "--- is target position open?! #{open} #{game_map.at(target)}"
      puts game_map.rows.inspect
      return false unless open #_positions.include?(target)
      player.status = :moving
      player.save!
      puts "=== scheduling update!!!!"
      schedule_update(player.next_active_tick, {target: target}) do |opts|
        target = opts[:target]
        puts "--- attempting to assign new player position #{target}..."
        player.x = target.x
        player.y = target.y
        player.status = :resting
        player.save!
        #CHANNEL << { :command => 'move', :player => player.name, :x => target.x, :y => target.y }.to_json
        broadcast_snapshot
        puts "--- moved to position #{target}!"
      end
      true
    else
      false
    end
  end

  # tick! is expecting to be called every 65ms or so
  def step
    if @tick
      puts "--- update! #@tick"
      @tick += 1
      updates_to_remove = []

      puts "=== checking for updates ******************************"
      scheduled_updates.each_with_index do |(t,opts,update_block),n|
        puts "--- checking on tasked schedule to be run at t=#{t}"
        if t <= @tick
          puts "--- running scheduled update!"
          update_block.call(opts)
          updates_to_remove << n
        end
      end
      updates_to_remove.each { |n| @scheduled_updates.delete_at(n) }
    end
    save!
  end

  def broadcast_snapshot
    #snapshot = World.current.to_hash # to_json(:element_name => 'world')
    #if @players.count > 0
    snapshot = {command: 'snapshot', tick: @tick}
    snapshot[:players] = players.map(&:to_hash) if players
    snapshot[:map] = game_map.rows
    #CHANNEL << snapshot #{command: 'snapshot', tick: @tick, players: player_hash, map: map}
     #{ #:command => 'snapshot', :tick => @tick, :players => @players.map(&:to_hash), :map => @game_map.rows }
    #end
    puts "---- broadcasting snapshot!"
    CHANNEL << snapshot.to_json
    snapshot
  end
end



## setup dm #####
DataMapper.finalize

DataMapper::Logger.new($stdout, :debug)

# in-memory sqlite db
DataMapper.setup(:default, 'sqlite::memory:')

DataMapper.auto_migrate!

$stdout.sync = true

## kick off simulation ####

## TODO this is a whole world of problems :/ figure out a better way to supervise this

puts "=== kicking off simulation!"

#world = World.current

# not great, crashes the api if the simulation goes down... :(
World.current.every(0.066) do
  World.current.broadcast_snapshot if World.current.tick % 10 == 0
  World.current.step
end
