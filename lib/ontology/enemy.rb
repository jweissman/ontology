# TODO make a freaking superclass this is a straight copy of hte player
# but have been trying to be good about only doing extract-class refactor when i encounter three of something
# so waiting for now
class Enemy
  include FirehosePublisher
  include DataMapper::Resource
  include Minotaur::Geometry

  # btw there's a uuid property so i don't have to type this everywhere
  property :id, String, key: true, default: lambda { |_,_| SecureRandom.uuid }
  property :name, String, default: 'Nameless Enemy'
  property :x, Integer
  property :y,               Integer
  property :last_moved_tick, Integer, default: 0
  property :status,          Enum[:resting, :moving, :attacking, :cooldown], default: :resting

  property :attack,  Integer, default: 2
  property :defense, Integer, default: 1
  property :hp,      Integer, default: 2

  property :speed,   Integer, default: 8

  belongs_to :world

  def collection_stream
    "/world/#{world.id}/enemies.json"
  end

  def collection_snapshot
    world.enemies.map(&:snapshot).to_json
  end

  def position
    Position.new(self.x, self.y)
  end

  def next_active_tick(current_tick=self.world.tick)
    puts "--- calculating player's next active tick!"
    [(last_moved_tick+speed), current_tick].max
  end
end
