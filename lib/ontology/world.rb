# TODO put this stuff somewhere else :/
class Fixnum
  def to_json(options = nil)
    to_s
  end
end

CHANNEL = EM::Channel.new

# a world keeps track of the state of the game, for now mostly player/enemy lists, events and game maps
class World
  include FirehosePublisher
  include DataMapper::Resource
  include Minotaur::Geometry::Directions

  after  :create, :build_map

  DIRECTIONS = {n: NORTH, e: EAST, s: SOUTH, w: WEST}

  has 1, :game_map
  has n, :players
  has n, :enemies
  has n, :events

  # really need an atlas that has multiple game maps
  # has n, :game

  property :id,   String, :key => true , :default => lambda { |_,_| SecureRandom.uuid }
  property :name, String, :default => 'hello'

  property :tick, Integer, :default => 0

  def build_map
    puts "==== BUILDING GAME MAP"
    self.game_map = GameMap.new
    puts "--- game map built! populating enemies.... (saved? #{saved?})"
    5.times do |n|
      puts "--- attempting to create enemy #{n}..."
      pos = open_positions.sample
      self.enemies.create x: pos.x, y: pos.y,name: 'Skeleton'
    end

    #self.events.create name: 'world created!'
    broadcast_event Event.new name: 'world created'

    # TODO traps/treasure
    # stairs/etc but we can expose that from minotaur (they're already being emplaced)
    # might be interesting to move enemies, etc., into minotaurs world generation utilities
    # self.game_map.create?
    puts "=== BUILD GAME MAP COMPLETE"
    save!
    #sleep 1
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
    broadcast
  end

  def last_moved_tick
    @last_moved_tick ||= false
  end

  COMPASS = {:n => NORTH, :e => EAST, :w => WEST, :s => SOUTH}
  def move(player, direction, uuid)
    #puts "--- Player attempting to move in direction #{direction}!"
    x, y = player.x, player.y
    direction = direction.slice(0,1).downcase.to_sym
    return unless COMPASS.has_key?(direction)

    #if COMPASS.has_key?(direction)
    #puts "--- I've got player #{player.name} at position #{x}, #{y} attempting to move in valid direction #{direction} in world #{self.name}..."
    dir = COMPASS[direction]
    target = Minotaur::Geometry::Position.new(DX[dir]+x, DY[dir]+y)
    open = open_positions.include?(target)

    # ...so here's kind of a hack here: not just that we're overriding movement as attacking ('ramming')
    # but furthermore note we're technically including the current player here as an 'enemy' (all players are listed as 'enemies')
    # shouldn't present a problem at the moment but it struck me as weird enough to merit notice/explanation
    # (the fix should probably be in enemy positions; parameterized to handle a 'from the perspective of...')
    # think we'll need that to finish combat anyway (from the AI sides)
    #
    attacking = enemy_positions.include?(target)
    #puts game_map.rows.inspect

    #puts "--- Is that position open? #{open}"
    return unless open || attacking
    #puts "=== It seems okay! Processing movement..."

    # restructured so that moving/attacking are immediate
    # i think this will be more responsive and still rate-limited at the server because of cooldowns...
    if open
      #puts "=== ACTUALLY PERFORMING MOVE OF PLAYER #{player.name} TO TARGET POSITION #{target}"
      player.x = target.x
      player.y = target.y
      player.save!

      # don't broadcast everything... create new move event with uid of move command so FE can ignore if necessary

      #evt = events.create(
      #evt.save!
      #evt.firehose
      broadcast_event Event.new({kind: :movement,
                                 name: "#{player.name} moved #{direction}",
                                 description: "#{player.name} moved #{direction} to #{target.x}, #{target.y}",
                                 details: {uuid: uuid, player_id: player.id, x: target.x, y: target.y}})


      #puts "=== broadcasting new event!"
      #self.events.each { |evt| evt.firehose }
      #firehose self.events.collect(&:snapshot).to_json, "/world/#{id}/events.json"

      #broadcast # if last_moved_tick
      #unless moved_last_tick
      #moved_last_tick = true
    elsif attacking
      player.status = :attacking
      # determine enemy, if damage is done, etc...
      enemy = enemies.first(x: target.x, y: target.y) #select { |e| e.position == target }.first
      return unless enemy && enemy.hp > 0 && enemy.status != :dying

      puts "--- found enemy: #{enemy.name}"
      puts "--- about to calculate damage"
      successful = 1 + rand(20) >= 8
      # TODO it's just players for now, maybe we should go ahead and simulate a mob for simplicity's sake
      attack_results = nil

      if successful
        puts "--- attack was successful! calculating damage and adjusting hit points..."
        damage = player.attack - enemy.defense
        puts "--- HANDLING DAMAGE"
        puts "--- attempting to adjust enemy hp: #{enemy.inspect}"
        enemy.hp -= damage
        enemy.save
        puts "--- enemy hp: #{enemy.hp}"
        if enemy.hp <= 0
          puts "==== KILL!******"
          puts "--- destroying enemy #{enemy.name} (#{enemy.id})!"
          player.x = enemy.x
          player.y = enemy.y
          enemy.destroy if Enemy.count(:id => enemy.id) > 0
          puts "--- destroy enemy #{enemy.name} (#{enemy.id}) complete!"
          attack_results = {
            kind: :death,
            name: "#{enemy.name} died",
            enemy_id: enemy.id,
            description: "#{enemy.name} took #{damage} lethal damage from #{player.name}!",
            details: { amount: damage }
          }
        else
          attack_results = {
            kind: :damage,
            name: "#{enemy.name} dealt #{damage} damage",
            enemy_id: enemy.id,
            description: "#{enemy.name} took #{damage} damage from #{player.name}!",
            details: { amount: damage }
          }
        end
      else
        puts "--- attack failed!"
        attack_results = {
         kind: :attack_failed,
         name: "#{player.name} missed #{enemy.name}",
         description: "#{enemy.name} took no damage from #{player.name}!"
        }
      end

      if attack_results
        puts "--- emitting event!"
        #events.create()
        broadcast_event Event.new(attack_results.deep_merge({details: { player: player.id, enemy: enemy.id }}))
        #event.broadcast
        #event.firehose

        # broadcast everything -- need to update enemy hp too. but could send JUST those, now...
        #broadcast
        #self.events.each { |evt| evt.firehose }
        #firehose self.events.collect(&:snapshot).to_json, "/world/#{id}/events.json"
      end
    end

    #puts "--- saving everything..."
    #player.save
    #save
    #true
    #end
    #else
    #  false
    #end
  end

  # seems decidedly odd to force this behavior back into a resource
  # also seems like this might have weird/unanticipated side effects
  # clients might totally 'miss' events, etc.
  # maybe should 'collect' events during a tick, and then push them out
  # ON the tick. (would help for 'known' simultaneous events.)
  # i'm hoping/thinking this will work because of the way firehose client processes
  # events, but i might well be missing something/making things worse :/
  # still...!
  # (in passing: i feel like a lot of the mechanics we're needing to are
  # are trying to replicate a 'shared-tick/delayed-client' system cheaply.
  # at some point it's going to be cheaper just to implement that properly than
  # hack around it.)
  # why aren't the events arriving...

  # okay, just websocket this event straight back out.
  def broadcast_event(evt)
    event_message = evt.attributes.merge(:command => 'game_event').to_json
    puts "=== broadcasting event: "
    CHANNEL << event_message

    #self.events << evt
    #evt.firehose
    #firehose self.events.map(&:attributes).to_json, "/world/#{id}/events.json"
  end

  # tick! is expecting to be called every 65ms or so
  def step
    #puts "--- tick!"
    if self.tick
      #moved_last_tick = false

      # update players
      #players.each { |p| p.step }

      #enemies.each { |e|
      #  # attempt to move in a random direction?
      #  if e.status == :resting
      #    if rand(6) > 4
      #      # TODO sanity check this, just straight overloading the method we were using for players
      #      move e, COMPASS.keys.sample.to_s
      #    end
      #  end
      #}

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
    snapshot_attrs = {}
    snapshot_attrs[:game_map_id]  = game_map.id if game_map
    snapshot_attrs[:player_ids]   = players.map(&:id)
    attributes.merge(snapshot_attrs)
  end

  def broadcast
    firehose reload.snapshot.to_json
    firehose(World.all.map(&:snapshot).to_json, "/worlds.json")

    #self.events.each { |evt| evt.firehose }
    #firehose self.events.collect(&:snapshot).to_json, "/world/#{id}/events.json"

    self.enemies.each { |e| e.firehose }
    if self.enemies.count > 0
      firehose self.enemies.collect(&:snapshot).to_json, "/world/#{id}/enemies.json"
    else
      firehose [].to_json, "/world/#{id}/enemies.json"
    end

    self.players.each { |p| p.firehose }
    firehose(self.players.collect(&:snapshot).to_json, "/world/#{id}/players.json")
  end
end

