class Ontology::Game::World < Ontology::Core::Simulation
  def state; @state ||= State.new end
  [:to_json, :step].each do |m|
    define_method(m) do |*args|
      state.send(m, *args)
    end
  end
end
