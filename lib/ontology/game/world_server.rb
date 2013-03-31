module Ontology::Game::WorldServer
  include RPC::AbstractServer
  def post_init
    # on local socket connection, expose the current world via RPC
    @obj = Ontology::Game::World.current
  end
end
