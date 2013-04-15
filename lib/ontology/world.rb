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
  has n, :enemies
  has n, :events

  property :id,   String, :key => true , :default => lambda { |_,_| SecureRandom.uuid }
  property :name, String, :default => 'hello'

  property :tick, Integer, :default => 0


  #property :updates, Object, :default => []

  def build_map
    puts "==== BUILDING GAME MAP"
    self.game_map = GameMap.create
    self.save!
    puts "--- game map built! populating enemies.... (saved? #{saved?})"
    #puts self.awesome_inspect
    sleep 2
    10.times do |n|
      puts "--- attempting to create enemy #{n}..."
      pos = open_positions.sample
      self.enemies << Enemy.new({x: pos.x, y: pos.y,name: 'Skeleton'})
    end
    save

    # TODO traps/treasure
    # stairs/etc but we can expose that from minotaur (they're already being emplaced)
    # might be interesting to move enemies, etc., into minotaurs world generation utilities
    # self.game_map.create?
    puts "=== BUILD GAME MAP COMPLETE"
    sleep 1
  end

  def player_positions
    players.map(&:position)
  end

  def enemy_positions
    enemies.map(&:position)
  end

  def blocked_positions
    player_positions + enemy_positions # TODO objects, mob
  end

  def open_positions
    self.game_map.all_empty_positions.reject do |p|
      blocked_positions.any? { |p2| p2.x == p.x && p2.y == p.y }
    end
  end

  def updates
    @scheduled_updates ||= []
  end

  def schedule_update(t=self.tick,opts={},&block)
    updates << [t,opts,block]
  end

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

  def cooldown(player)
    player.status = :cooldown
    player.last_moved_tick = self.tick
    player.save
    # wooooooooo! :)
    schedule_update(player.next_active_tick, {player: player}) do |opts|
      puts "=== COOLDOWN COMPLETE, PLAYER IS RESTING!"
      player = opts[:player]
      player.status = :resting
      player.last_moved_tick = self.tick
      puts player.inspect
      player.save
    end
  end

  COMPASS = {:n => NORTH, :e => EAST, :w => WEST, :s => SOUTH}
  def move(player, direction)
    if player.status == :moving || player.status == :cooldown
      puts "=== PLAYER #{player.name} IS ALREADY MOVING/COOLING DOWN, IGNORING MOVE COMMAND (world #{self.name})"
      return
    end

    puts "--- Player attempting to move!"


    x, y = player.x, player.y
    direction = direction.slice(0,1).downcase.to_sym

    if COMPASS.has_key?(direction)
      puts "--- I've got player #{player.name} at position #{x}, #{y} attempting to move in valid direction #{direction} in world #{self.name}..."
      dir = COMPASS[direction]
      target = Minotaur::Geometry::Position.new(DX[dir]+x, DY[dir]+y)
      open = open_positions.include?(target)

      # ...so here's kind of a hack here: not just that we're overriding movement as attacking ('ramming')
      # but furthermore note we're technically including the current player here as an 'enemy' (all players are listed as 'enemies')
      # shouldn't present a problem at the moment but it struck me as weird enough to merit notice/explanation
      # (the fix should probably be in enemy positions; parameterized to handle a 'from the perspective of...')
      # think we'll need that to finish combat anyway (from the AI sides)
      attacking = enemy_positions.include?(target)

      #puts game_map.rows.inspect
      puts "--- Is that position open? #{open}"
      return false unless open || attacking
      puts "=== It seems okay! Processing movement..."

      # restructured so that moving/attacking are immediate
      # i think this will be more response and still rate-limited at the server because of cooldowns
      if open
        player.status = :moving
        #schedule_update(player.next_active_tick, {target: target, player: player}) do |opts|
        #  target = opts[:target]
        #  player = opts[:player]
        puts "=== ACTUALLY PERFORMING MOVE OF PLAYER #{player.name} TO TARGET POSITION #{target}"
        player.x = target.x
        player.y = target.y
        cooldown(player)
          #player.status = :cooldown
          #player.last_moved_tick = self.tick
          #player.save
          ## wooooooooo! :)
          #schedule_update(player.next_active_tick, {player: player}) do |opts|
          #  puts "=== COOLDOWN COMPLETE, PLAYER IS RESTING!"
          #  player = opts[:player]
          #  player.status = :resting
          #  player.last_moved_tick = self.tick
          #  puts player.inspect
          #  player.save
          #end
        #end
      elsif attacking
        player.status = :attacking
        # determine enemy, if damage is done, etc
        enemy = enemies.select { |e| e.position == target }.first

        if enemy
          puts "--- found enemy: #{enemy.name}"
          puts "--- about to calculate damage"
          successful = 1 + rand(20) >= 8
          # TODO it's just players for now, maybe we should go ahead and simulate a mob for simplicity's sake
          attack_results = if successful
           puts "--- attack was successful! calculating damage and adjusting hit points..."
           damage = player.attack - enemy.defense
           enemy.hp = enemy.hp - damage

           enemy.save

           if enemy.hp <= 0
             {
               kind: :death,
               name: "#{enemy.name} died",
               description: "#{enemy.name} took #{damage} lethal damage from #{player.name}!",
               details: { amount: damage }
             }
           else
             {
               kind: :damage,
               name: "#{enemy.name} dealt #{damage} damage",
               description: "#{enemy.name} took #{damage} damage from #{player.name}!",
               details: { amount: damage }
             }
           end
         else
           puts "--- attack failed!"
           {
             kind: :attack_failed,
             name: "#{player.name} missed #{enemy.name}",
             description: "#{enemy.name} took no damage from #{player.name}!"
           }
          end

          puts "--- emitting event!"
          events.create(attack_results.deep_merge({details: { player: player.id, enemy: enemy.id }}))
          cooldown(player)
        end



        #schedule_update(player.next_active_tick, {successful: success, target: target, source: player, amount: amt}) do |opts|
        #  puts "=== PLAYER WOULD BE ATTACKING..."
        #  attack_results = if opts[:successful]
        #    # fe should receive this event and emit a sound
        #    events.create({
        #    }).collection_sync
        #  else
        #  end
        #
        #  events.create(attack_results)
        #  cooldown(player)
        #  # so maybe each world has its own out of band websocket
        #  # so we can fire events straight at that world
        #  # alternatively... -- although that sounds simpler
        #  # it might be better to structure it as a restful resource
        #  # /world/:id/events.json
        #  # i just worry about synchroncitiy -- but that's not really been a problem
        #  # we can tie into new events relatively easily on the frontend in that way
        #  # a model without a view, tied to a world like the players list
        #  # shouldn't be too bad :)
        #  # feels slightly better because we aren't relying on the websocket on this side
        #  # which i think is great
        #end
      end

      player.save
      puts "--- And scheduling move!!!"

      # ?
      save
      #puts self.inspect
      true
    else
      false
    end
  end

  #def updates
  #  self.scheduled_updates ||= []
  #end


  # tick! is expecting to be called every 65ms or so
  def step
    #puts "--- tick!"
    if self.tick

      # update players
      #players.each { |p| p.step }

      #puts "--- world #{self.name} tick #{self.tick} (updates: #{updates.count})" if self.tick % 10 == 0
      #puts self.inspect if self.tick % 3 == 0

      updates_to_remove = []
      puts "--- scheduled updates to consider: #{updates.count} [world #{self.name}]" if updates_to_remove.count > 0
      updates.each_with_index do |(t,opts,update_block),n|
        puts "=== comparing time #{t} with current tick #{self.tick}"
        if t <= self.tick

          puts "--- running scheduled update #{n} at t=#{t}!"
          #@updates_to_remove ||= []
          puts "--- updates to remove: #{updates_to_remove} (within block...?)"

          update_block.call(opts)
          updates_to_remove << n
          #scheduled_updates.delete(n)

        end
      end
      updates_to_remove.each { |n| updates.delete_at(n) }

      self.tick += 1
      self.save! # ...? :) should be keeping things in sync, right?
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
    #puts "---- looking at players: #{players.inspect}"
    snapshot_attrs[:players]     = players.map(&:id) # unless active_player_ids.empty?
    snapshot_attrs[:enemies]     = enemies.map(&:id)
    attributes.reject {|k,v| k=='updates'}.merge(snapshot_attrs) #, map_id: game_map.id)
  end
end

