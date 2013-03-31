class Ontology::API::WorldClient < BlankSlate
  def initialize sock = '/tmp/world.sock'
    @sock = ::UNIXSocket.open(sock)
  end
  def method_missing *meth
    data =::Marshal.dump(meth)
    @sock.send([data.respond_to?(:bytesize) ? data.bytesize : data.size, data].pack('Na*'), 0)
    ::Marshal.load @sock.recv(*@sock.recv(4).unpack('N'))
  end
end
