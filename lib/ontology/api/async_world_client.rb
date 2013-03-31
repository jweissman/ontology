class Ontology::API::AsyncWorldClient < BlankSlate
  def initialize sock = '/tmp/world.sock'
    @sock = ::EventMachine.connect sock, ::Ontology::API::RequestHandler
  end
  def method_missing *meth, &blk
    @sock.queue << blk
    @sock.send_object(meth)
  end
end

