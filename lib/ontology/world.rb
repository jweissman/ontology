# TODO put this stuff somewhere else :/
class Fixnum
  def to_json(options = nil)
    to_s
  end
end

CHANNEL = EM::Channel.new

# a world keeps track of the state of the game, for now mostly player lists and game maps
class World
  include FirehosePublisher
  include DataMapper::Resource
  include Minotaur::Geometry::Directions

  before  :create, :build_map

  #after  :create,  :collection_sync
  #after  :destroy, :collection_sync
  #
  #after  :save,   :sync

  DIRECTIONS = {n: NORTH, e: EAST, s: SOUTH, w: WEST}

  has 1, :game_map #, :default => lambda { |_,_| GameMap.new }
  has n, :players

  property :id,   String, :key => true , :default => lambda { |_,_| SecureRandom.uuid }
  property :name, String, :default => 'hello'

  property :tick, Integer, :default => 0

  def build_map
    puts "==== BUILDING GAME MAP"
    self.game_map = GameMap.create
    #self.game_map.save
  end

  def open_positions
    puts "--- attempting to find open an open position in game map..."
    self.game_map.all_empty_positions - players.all(&:positions)
  end

  def scheduled_updates
    @scheduled_updates ||= []
  end

  def schedule_update(t=@tick,opts={},&block)
    puts "--- scheduling update at t=#{t}..."
    @scheduled_updates << [t,opts,block] if block_given?
  end

  #def join(player)
  #  puts "--- #{player.name} joins the realm #{name}!*******************"
  #  new_position = open_positions.sample
  #  puts "=== player attempting to be placed at #{new_position}"
  #  puts "--- #{new_position.inspect}"
  #  #player.update({x:new_position.x,y:new_position.y})
  #  #player.update world: self
  #  puts "=== current list of players: #{self.players.inspect}"
  #
  #  # the below is pure anger
  #  # (and likely misunderstanding of DM)
  #  #puts "--- updating position..."
  #  #player.x = new_position.x
  #  #player.y = new_position.y
  #  ##player.save
  #  #puts "--- position updated!"
  #  #
  #  #puts "--- attempting to include player in world..."
  #  #player.world = self #self
  #  #puts "--- player: #{player.inspect}"
  #
  #  player.update(x: new_position.x, y: new_position.y)
  #  player.save
  #  self.players << player
  #  # why doesn't this sync the world...?
  #  #save
  #  self.players.save!
  #  player.save!
  #  self.save!
  #
  #  # just save everything! man
  #  puts "--- everything saved...!"
  #  puts "--- world inspect: #{self.inspect}"
  #  puts "--- world players: #{self.players.inspect}"
  #  puts "--- (THIS) player inspect: #{player.inspect}"
  #  puts "--- might want to player collection sync manually here?"
  #  self.save
  #  self.players.save
  #  player
  #  puts "--- world players: #{self.players.inspect}"
  #  sync
  #  collection_sync
  #end

  def leave(player)
    puts "--- #{player.name} leaves the realm #{name}**********"
    player.world = nil
    player.save!
    puts "--- player should no longer be in world...!"

    # okay, sync world
    sync

    # both global players and particular world players could be updtaed
    player.collection_sync
    Player.first.collection_sync
  end

  #def active_player_ids
  #  self.players.map(&:id)
  #end

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
    #puts "--- tick!"
    if self.tick
      updates_to_remove = []
      scheduled_updates.each_with_index do |(t,opts,update_block),n|
        if t <= self.tick
          puts "--- running scheduled update!"
          update_block.call(opts)
          updates_to_remove << n
        end
      end
      updates_to_remove.each { |n| @scheduled_updates.delete_at(n) }

      self.tick += 1
      self.save!
    end
  end
  #
  #def chat(*args)
  #  puts "=== CHAT NOT IMPLEMENTED YET GO AWWAY"
  #end

  def snapshot
    # TODO handle map by reference too...?
    #game_map.save
    snapshot_attrs = {}
    snapshot_attrs[:game_map_id] = game_map.id if game_map
    puts "---- looking at players: #{players.inspect}"
    snapshot_attrs[:players]     = players.map(&:id) # unless active_player_ids.empty?
    attributes.merge(snapshot_attrs) #, map_id: game_map.id)
  end
end

