class World
  include Celluloid
  #include Celluloid::Notifications

  attr_accessor :state
  def initialize
    @state = OpenStruct.new
    @state.value = 0
    @state.players = []
    @state.map = []
  end

  def simulate #(env)
    @state.value += 1
    #puts "--- step...! (#{@state.value})"
    #if @state.value % 10 == 0
    #  puts "=== FOR YOU"
    #  env.channel << ['world', 'OH YEAH FOR YOU']
    #end
  end

  class << self
    def current
      @current ||= World.new
    end
  end
end
