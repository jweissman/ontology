require 'data_mapper'
require 'minotaur'

class Fixnum
  def to_json(options = nil)
    to_s
  end
end

# TODO cleanup the below...
#class Model
#  include DataMapper::Resource
#  # logic for talking with firehose
#end
#
#class Actor
#  include Celluloid
#  # logic for talking with websocket clients?
#end

class Player
  include DataMapper::Resource

  property :id,   Serial
  property :name, String, :default => 'Guest'
  property :position, Json # :default => [0,0]

  property :last_moved_tick, Integer

  property :speed, Integer, :default => 14 # smaller is faster (less frames between move-throttling)

  validates_uniqueness_of :name
  validates_uniqueness_of :position

  #def position
  #  [x, y]
  #end

  def next_active_tick(current_tick=World.current.tick)
    [(last_moved_tick+speed), current_tick].max
  end
end

#
# (keep thinking i should just go ahead and submodule minotaur at this rate...)
#  [ done! ]
#
class GameMap #< Minotaur::Geometry::Grid
  include DataMapper::Resource
  #include Celluloid
  #extend Minotaur::Extruders::RecursiveBacktrackingExtruder

  property :id,    Serial
  property :name,  String

  property :width,   Integer, :default => 10
  property :height,  Integer, :default => 10
  property :rows,    Json,    :default => lambda { |r,p| r.labyrinth.to_a.to_json }
  #property :labyrinth, Object, :default => lambda { |r,p|
  #  Minotaur::Labyrinth.new({
  #      width: r.width/2,
  #      height: r.height/2
  #  })
  #}


  attr_accessor :labyrinth
  def labyrinth
    @labyrinth ||= Minotaur::Labyrinth.new({
      width: @width,
      height: @height
    })
  end

  # all stuff from minotaur's grid ... need to make that a module or helpers
  def at(position)
    #puts "--- attempting to consider position #{position} in labyrinth: "
    #p labyrinth
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

  def schedule_update(t,&block)
    @scheduled_updates << [t,block] if block_given?
  end

  def join(player_name)
    puts "--- join!"
    new_position = open_positions.sample

    puts "=== player attempting to be placed at #{new_position}"
    puts "--- #{new_position.inspect}"

    Player.create({name:player_name,position:[new_position.x,new_position.y]})
  end

  def move(player, direction)
    puts "--- move!"
    target = player.position.translate(DIRECTIONS(direction.slice(0,1).downcase.to_sym))
    return false unless open_positions.include?(target)
    schedule_update(player.next_active_tick) do
      puts "--- attempting to assign new player position..."
      #puts "--- current position: #{player}"
      player.position = target #.load(target.to_json)
      player.save!
    end
  end

  # tick! is expecting to be called every 65ms or so
  def step
    if @tick
      puts "--- update! #@tick"
      #puts "=== why don't we have a tick?!"
      @tick += 1
      updates_to_remove = []
      scheduled_updates.each_with_index do |(t,update_block),n|
        if t==@tick
          puts "--- running scheduled update!"
          update_block.call
          updates_completed << n
        end
      end
      updates_to_remove.each { |n| @scheduled_updates.delete_at(n) }
    end
    save!
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
World.current.every(0.66) { |_|
  puts "---tick"
  World.current.step
}
