# TODO validate on create...
require 'active_model'

# TODO integrate warden and get a remotely adult-looking auth layer

class Player #< Struct.new(:name, :position)
  #include DataMapper::Resource ...?
  include ActiveModel::Validations

  # TODO move to support...
  class UniqueValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, "must be unique" if record.class.any? { |p| value == p.attributes[attribute] }
    end
  end

  attr_accessor :id, :name, :position

  validates_presence_of :id, :name, :position
  validates :name, :unique => true, :presence => true

  def attributes #(key)
    @attributes ||= {} #[key]
  end

  class << self
    def registry
      @registry ||= {}
    end

    def register!(instance)
      puts "=== Attempting to register #{instance.inspect}"
      puts "--- Current registry: #{registry.inspect}"
      unless instance.valid?
        raise "Invalid #{instance.class.name}: #{instance.errors}"
      end

      registry[instance.id] = instance
    end

    def all
      registry.values
    end

    def any?(&blk); all.any?(&blk) end

    def exists?(id); any? { |r| r.id == id } end

    def find_by_name(name)
      all.select { |p| p.name == name }.first
    end

    def create!(attributes={})
      new(attributes).save!
    end
  end

  def initialize(attrs={}) # aid, name, position)
    unless attrs.nil?
      attrs.each do |name, value|
        send("#{name}=", value)
      end
    end
    @attributes = attrs

    #puts "--- creating new player at #{position} with name #{name}"
    @id       = SecureRandom.uuid
    @attributes[:id] = @id


    #if valid?
    #  Player.register!(self)
    #else
      #raise "Player isn't valid!"
      #puts "--- Player errors: #{errors}"
    #end

  end

  def save!
    puts "--- Attempting to register player!"
    Player.register!(self)
  end

  def read_attribute_for_validation(key)
    @attributes[key]
  end

  # if player_name is unique...?
  #def add_player id, name='Default Name'
  #  #puts "=== was told to add player with name: #{name}"
  #  open_pos  = open_positions.sample
  #  player    = Player.new(id, name, open_pos)
  #  @players << player
  #  #puts "--- added player: #{player.inspect}"
  #  player
  #end
  #
  #def player_named name
  #  @players.reject { |p| p.name != name }.first
  #end
end

class Map
  attr_accessor :cells, :height, :width
  def initialize(opts={})
    @height = opts[:height] || 10
    @width  = opts[:width]  || 10
    @cells  = opts[:cells]  || [[0,1,1,0,1,1,0,1,0],
                                [0,0,0,0,0,1,0,0,0],
                                [1,1,0,1,1,1,0,0,0],
                                [0,0,0,0,0,1,0,0,1],
                                [0,1,0,1,0,0,0,1,0],
                                [0,1,0,0,1,0,1,1,0],
                                [0,1,0,0,0,1,0,1,1],
                                [1,1,0,1,1,0,1,0,0],
                                [0,0,0,0,1,1,0,0,1],
                                [1,1,1,0,1,0,1,0,0]]
  end

  def each_position
    (@width-1).times do |x|
      (@height-1).times do |y|
        yield [1+x,1+y]
      end
    end
  end

  def each_open_position(player_positions)
    each_position do |position|
      yield position unless player_positions.include?(position)
    end
  end
end


class World
  include Celluloid
  attr_accessor :players, :map
  def initialize
    #@players = []
    @map = Map.new
  end

  def open_positions
    open = []
    @map.each_open_position(players.map(&:position)) { |p| open << p }
    open
  end

  def players; Player.all end

  # if player_name is unique...?
  def add_player id, name='Default Name'
    #puts "=== was told to add player with name: #{name}"
    if Player.exists?(id) || Player.any? { |p| p.name == name }
      puts "=== was asked to add a player, but just chilling as it seems that player exists (or another has the same name/id...?)"
    else
      open_pos  = open_positions.sample
      Player.create!({id: id, name: name, position: open_pos})
    end

    #player.save! if player.valid?
    #@players << player
    #if player.valid?
    #   player
    #else
      #puts "=== #{player.errors}"
    #end
    #puts "--- added player: #{player.inspect}"
    #player
  end
  #
  #def player_named name
  #  @players.reject { |p| p.name != name }.first
  #end

  COMPASS = {n: [0,-1], e: [1,0], s: [0,1], w:[-1,0] }
  def translate_position position, direction
    position + COMPASS[direction.slice(0,1).downcase.to_sym]
  end

  def move_player name, direction
    target_cell = translate_position(player_named(name).position, direction)
    return false unless open_positions.include? target_cell
    Player.find_by_name(name).position = target_cell
    true
  end

  def simulate
    #@state.value += 1

    # currently a no-op :(

    # it's okay! :) promise...
  end

  class << self
    def current
      @current ||= World.new
    end
  end
end
