require 'rubygems'
require 'eventmachine'
require 'socket'

class World
  attr_reader :value
  def initialize
    @value = 0
  end

  def step!
    puts "=== world step!"
    @value = @value + 1
  end

  #def to_json
  #  { :value => @value }
  #end
end

world = World.new

module WorldServer
  include EM::P::ObjectProtocol
  def post_init
    @obj = world
  end

  def receive_object(method)
    send_object @obj.__send__(*method)
  end

  def unbind
    @obj = nil
  end
end

EM.run{
  FileUtils.rm '/tmp/world.sock' if File.exists? '/tmp/world.sock'
  EM.start_server '/tmp/world.sock', WorldServer

  # use a thread because the client is blocking
  #Thread.new{
  #  o = RPCClient.new
  #  o[1] = :a
  #  o[2] = :b
  #  o[3] = :c
  #  p o.keys
  #  p o.values
  #}
  #
  #o = AsyncRPCClient.new
  #o[:A] = 99
  #o[:B] = 98
  #o[:C] = 97
  #o.keys{ |keys| p(keys) }
  #o.values{ |vals| p(vals) }
  puts "==== ONTOLOGY"
}


#require "ontology/version"
##require 'goliath'
#require 'eventmachine'
#require 'drb'
#
##require "ontology/world"
##require "ontology/model"
##require "ontology/actor"
##require "ontology/controller"
#
##module Ontology
##  # Your code goes here...
##  def receive_data(data)
##    p data
##  end
##end
##
##EventMachine.connect '127.0.0.1', 6666, Ontology
#
#interrupted = false
#
#trap("INT") {
#  puts "--- interrupted..."
#  interrupted = true
#}
#
#EventMachine.run {
#  EventMachine.add_periodic_timer(1) {
#    world.step!
#    if interrupted
#      puts "--- bye!"
#      DRb.stop_service
#      exit
#    end
#  }
#
#
#  DRb.start_service 'druby://:9000', world
#  puts "--- ontology server running at #{DRb.uri}"
#
#
#  # safe with event machine?
#  puts "--- joining thread... :( ?"
#  #DRb.thread.join
#}
