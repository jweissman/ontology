require 'rubygems'
require 'eventmachine'
require 'socket'
require 'goliath'
#require 'drb'
#
#world = DRbObject.new nil, 'druby://:9000'

#unless defined?(BlankSlate)
#  if defined?(BasicObject)
#    BlankSlate = BasicObject
#  else
#    class BlankSlate
#      instance_methods.each { |m| undef_method m unless m =~ /^__/ }
#    end
#  end
#end

class WorldClient #< BlankSlate
  def initialize sock = '/tmp/world.sock'
    @sock = UNIXSocket.open(sock)
  end
  def method_missing *meth
    data = Marshal.dump(meth)
    @sock.send([data.respond_to?(:bytesize) ? data.bytesize : data.size, data].pack('Na*'), 0)
    Marshal.load @sock.recv(*@sock.recv(4).unpack('N'))
  end
end

module Handler
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

class AsyncWorldClient #< BlankSlate
  def initialize sock = '/tmp/world.sock'
    @sock = EventMachine.connect sock, Handler
  end
  def method_missing *meth, &blk
    @sock.queue << blk
    @sock.send_object(meth)
  end
end


class Stream < Goliath::API


  def response(env)
    #counter.step!
    world = AsyncWorldClient.new
    puts "The counter value is #{world.value}"

    pt = EM.add_periodic_timer(1) do
      env.stream_send("{value: #{world.value}\n")
      #world.step!
      #i += 1
    end

    EM.add_timer(10) do
      pt.cancel

      env.stream_send("!! BOOM !!\n")
      env.stream_close
    end

    [200, {}, Goliath::Response::STREAMING]
  end
end
