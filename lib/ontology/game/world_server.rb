module Ontology::Game::WorldServer
  attr_reader :world
  include EM::P::ObjectProtocol

  def post_init
    # on local socket connection, expose the current world via RPC
    @world = Hash.new #Ontology::Game::World.current
  end

  def receive_object method
    send_object @world.__send__(*method)
  end

  def unbind
    @world = nil
  end
end
