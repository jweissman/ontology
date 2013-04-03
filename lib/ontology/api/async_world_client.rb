#class Ontology::API::AsyncWorldClient < RPC::AsyncClient #BlankSlate
#  def initialize sock = '/tmp/world.sock'
#    super(sock)
#  end
#
#  #def each_event
#  #  @obj.each_event do |evt|
#  #
#  #  end
#  #end
#  #module RequestHandler
#  #  include EM::P::ObjectProtocol
#  #  def post_init
#  #    @queue = []
#  #  end
#  #  attr_reader :queue
#  #  def receive_object obj
#  #    if cb = @queue.shift
#  #      cb.call(obj)
#  #    end
#  #  end
#  #end
#  #
#  #def initialize sock = '/tmp/world.sock'
#  #  @sock = ::EventMachine.connect sock, RequestHandler
#  #end
#  #
#  #def method_missing *meth, &blk
#  #  @sock.queue << blk
#  #  @sock.send_object(meth)
#  #end
#end
#
