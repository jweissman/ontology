class Ontology::Game::World # < Ontology::Core::Simulation
  attr_reader :state

  class << self
    def current
      @current ||= Ontology::Game::World.new
    end
  end

  def initialize
    @state = OpenStruct.new
    @state.value = 0

    # a new world is by default the 'current' world
    # (single threaded, single world model for now...)
    #Ontology::Game::World.current = self
  end

  def step!
    puts "--- step!"
    puts "=== state: #@state"
    @state.value += 1
  end

  def to_s
    #"{'value': #{@state.value}"
    {value: @state.value}.to_json.to_s
  end
end
