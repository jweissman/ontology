class GameMap #< RemoteActor
  include FirehosePublisher
  include DataMapper::Resource

  #after  :create, :collection_sync
  #before :save,   :sync

  property :id,      String, key: true, :default => lambda { |_,_| SecureRandom.uuid }
  property :name,    String, default: 'just a map'

  property :width,   Integer, default: 30
  property :height,  Integer, default: 30
  property :rows,    Json,    default: lambda { |r,_|  r.labyrinth.to_a.to_json } #
    #r.labyrinth
  #  Array.new(r.width) { Array.new(r.height) {0}}
  #}
  #[[0,0,0,0,0],
  #                                                      [0,0,0,0,0],
  #                                                      [0,0,0,0,0],
  #                                                      [0,0,0,0,0],
  #                                                      [0,0,0,0,0]].to_json } #

  belongs_to :world #, required: false

  attr_accessor :labyrinth
  def labyrinth
    @labyrinth ||= Minotaur::Labyrinth.new({
       width: (@width/3).to_i,
       height: (@height/3).to_i,
       extruder: Minotaur::Extruders::AssemblingRoomExtruder
    })
    #puts "--- created labyrinth: "
    #puts @labyrinth.to_a.to_json
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
