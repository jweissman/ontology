class Player # < RemoteActor
  include FirehosePublisher
  include DataMapper::Resource

  property :id,   String, key: true, :default => lambda { |_,_| SecureRandom.uuid }
  property :name, String, :default => 'Guest'
  property :x,    Integer
  property :y,    Integer

  property :last_moved_tick, Integer, :default => 0
  property :status, Enum[ :resting, :moving,:attacking, :cooldown ], :default => :resting


  property :attack,  Integer, default: 2
  property :defense, Integer, default: 1
  property :hp,      Integer, default: 15

  property :speed, Integer, default: 0 # smaller is faster :)

  belongs_to :world, required: false

  validates_uniqueness_of :name

  #after  :create, :collection_sync
  #before :save,   :sync

  # nested collection stream for players in worlds -- still has a normal instance stream...
  # maybe that's weird? :)
  # the idea is to capture the fact that the domain permits players to 'float'; not be in a world
  # and also it would seem convenient for clients to be able to connect to the API endpoint
  def collection_stream
    world ? "/world/#{world.id}/players.json" : super
  end

  def collection_snapshot
    world ? world.players.map(&:snapshot).to_json : super
  end

  def position
    Minotaur::Geometry::Position.new(self.x,self.y)
  end

  # TODO move leaving/joining world bizlogic here... (makes more sense semanticaly at the very least)

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

  def next_active_tick(current_tick=self.world.tick)
    puts "--- calculating player's next active tick!"
    [(last_moved_tick+speed), current_tick].max
  end


  #COOLDOWN_RATE = 25
  #def step
  #  puts "=== updating player #{self.name}"
  #  if self.status == :cooldown && last_moved_tick+COOLDOWN_RATE <= self.world.tick
  #    self.status = :resting
  #    save
  #  end
  #end
end
