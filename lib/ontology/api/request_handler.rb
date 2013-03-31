module Ontology::API::RequestHandler
  include EM::P::ObjectProtocol
  def post_init
    @queue = []
  end
  attr_reader :queue
  def receive_object obj
    if cb = @queue.shift
      cb.call(obj)
    end
  end
end
