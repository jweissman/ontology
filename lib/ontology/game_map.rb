class GameMap #< RemoteActor
  include FirehosePublisher
  include DataMapper::Resource

  property :id,      String, key: true, :default => lambda { |_,_| SecureRandom.uuid }
  property :name,    String, default: 'just a map'

  property :width,   Integer, default: 60
  property :height,  Integer, default: 60
  property :rows,    Json,    default: lambda { |r,_|  r.labyrinth.to_a.to_json }
  belongs_to :world
  attr_accessor :labyrinth
  def labyrinth

    @labyrinth ||= Minotaur::Labyrinth.new({
       width: (@width/3).to_i,
       height: (@height/3).to_i,
       extruder: Minotaur::Extruders::AssemblingRoomExtruder
    })
  end

  # all stuff from minotaur's grid ... need to make that a module or helpers  (rethink this whole thing really :)
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

  ####

  #def sync
  #  puts "---- map sync!"
  #  firehose_sync
  #end
end
