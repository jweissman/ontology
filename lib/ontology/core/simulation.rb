#
#
#
class Ontology::Core::Simulation
  def initialize
    @state = Ontology::Core::State.new
  end
  def run!
    simulate! while true
  end
end
