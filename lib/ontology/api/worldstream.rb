#require 'ontology'
#require 'socket'
#require 'eventmachine'
#require 'goliath'
#
#$world = Ontology::API::WorldClient.new
##puts "--- world client: #{$world}"
#
#class Worldstream < Goliath::API
#  def response(env)
#    pt = EM.add_periodic_timer(1) do
#      #world =
#      #puts "=== TIMER"
#      #puts "--- world: #{world.inspect}"
#      #puts "--- value: #{world.state.inspect}"
#
#      env.stream_send($world.state.to_s + "\n")
#    end
#
#    EM.add_timer(10) do
#      puts "****** boom! ******"
#      pt.cancel
#      env.stream_send("!! BOOM !!\n")
#      env.stream_close
#    end
#
#    [200, {}, Goliath::Response::STREAMING]
#  end
#end
