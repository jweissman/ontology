class Player
  attr_accessor :name, :position
  def initialize(name, position)
    @name = name
    @position = position
  end
end

class Map
  attr_accessor :cells, :height, :width
  def initialize(opts={})
    @height = opts[:height] || 10
    @width  = opts[:width]  || 10
    @cells  = Array.new(@height) { Array.new(@width) {0}}
  end

  def each_position
    @width.times do |x|
      @height.times do |y|
        yield [x,y]
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
    @players = []
    @map = Map.new
  end

  def open_positions
    open = []
    @map.each_open_position(@players.map(&:position)) { |p| open << p }
    open
  end

  def add_player name
    @players << Player.new(name, open_positions.sample)
  end

  def player_named name
    @players.reject { |p| p.name != name }.first
  end

  COMPASS = {n: [0,-1], e: [1,0], s: [0,1], w:[-1,0] }
  def translate_position position, direction
    position + COMPASS[direction.slice(0,1).downcase.to_sym]
  end

  def move_player name, direction
    target_cell = translate_position(player_named(name).position, direction)
    raise "Invalid move" unless open_positions.include? target_cell
    player_named(name).position = target_cell
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
