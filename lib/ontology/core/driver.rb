require 'ontology'

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
$stdout.sync = true

class Ontology::Core::Driver

  class << self
    attr_accessor :api_server_pid, :interrupted

    def trap_interrupts!
      @interrupted = false
      trap("INT") { @interrupted = true }
    end

    def core_process!
      EM.run{
        puts "*********************** ontology server #{Ontology::VERSION} running ***********************"

        FileUtils.rm '/tmp/rpc.sock' if File.exists? '/tmp/rpc.sock'
        EM.start_server '/tmp/rpc.sock', Ontology::Game::WorldServer

        #EM.add_periodic_timer(1) {
        #  Ontology::Game::World.current.step!
        #  if @interrupted
        #    puts "--- bye!"
        #    exit
        #  end
        #}
      }
    end

    def launch!
      puts "This is the master worlds process."
      trap_interrupts!
      #fork_api_server!
      core_process!
    end
  end
end

Ontology::Core::Driver.launch!
