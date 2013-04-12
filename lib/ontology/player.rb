class Player # < RemoteActor
  include FirehosePublisher
  include DataMapper::Resource

  property :id,   String, key: true, :default => lambda { |_,_| SecureRandom.uuid }
  property :name, String, :default => 'Guest'
  property :x,    Integer
  property :y,    Integer
  property :last_moved_tick, Integer, :default => 0
  property :status, Enum[ :resting, :moving  ], :default => :resting

  property :speed, Integer, :default => 3

  belongs_to :world, required: false

  validates_uniqueness_of :name

  #after  :create, :collection_sync
  #before :save,   :sync

  # nested collection stream for players in worlds -- still has a normal instance stream...
  # maybe that's weird? :)
  def collection_stream
    world ? "/world/#{world.id}/players.json" : super
  end

  def collection_snapshot
    world ? world.players.map(&:snapshot).to_json : super
  end

  def position
    Minotaur::Geometry::Position.new(self.x,self.y)
  end

  #def update_position(pos)
  #  self.x = pos.x
  #  self.y = pos.y
  #  #save!
  #  puts "=== update player position: #{inspect}"
  #  #save!
  #end
  #
  #def update_world(w)
  #  self.world = w
  #  w.players << self
  #  #w.save!
  #
  #  save!
  #  puts "=== update player world: #{inspect}"
  #  #save!
  #end

  def next_active_tick(current_tick=World.current.tick)
    [(last_moved_tick+speed), current_tick].max
  end
end
