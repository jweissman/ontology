class World
  include Celluloid

  attr_accessor :state
  def initialize
    @state = OpenStruct.new
    @state.value = 0
    @state.players = []
    @state.map = []
  end

  def simulate
    @state.value += 1
  end

  class << self
    def current
      @current ||= World.new
    end
  end
end
