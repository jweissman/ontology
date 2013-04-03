# WOOOOOO! AND FROM SCRATCH WITH REEL! ....jesus

require 'ostruct'
#require 'reel'
require 'celluloid'


require 'goliath'
require 'goliath/websocket'
#require 'ontology'

require 'ontology/version'
require 'ontology/world'



#module Ontology
#end

#      # hmmm, feel like i'm missing something here, but...!





#  class WorldServer < Reel::Server
#    def initialize(host="127.0.0.1",port=9000)
#      super(host,port,&method(:on_connection))
#
#      puts "--- world server!"
#
#      # hmmm, feel like i'm missing something here, but...!
#      World.current.every(0.05) do
#        World.current.simulate
#      end
#
#      puts "--- ...back in master!"
#      puts "--- #{World.current.state.value}"
#    end
#
#    def on_connection(connection)
#      while request = connection.request
#        case request
#        when Reel::Request
#          handle_request(request)
#        when Reel::WebSocket
#          handle_websocket(request)
#        end
#      end
#    end
#
#    def handle_request(request)
#      request.respond :ok, <<-HTML
#      <!DOCTYPE html>
#      <html>
#        <head>
#          <title>worldsockets test page</title>
#          <script src='http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js'></script>
#          <script>
#            function debug(str)
#            {
#                $("#debug").append("<p>" + str + "</p>");
#            };
#
#            $(document).ready(function()
#            {
#                if (!("WebSocket" in window))
#                {
#                    alert("We're sorry, but WebSockets are not available in this browser.");
#                    return;
#                }
#
#                var ws = new WebSocket("ws://localhost:9000");
#                ws.onmessage = function(evt) { $("#msg").append("<p>" + evt.data + "</p>"); };
#                ws.onclose   = function() { debug("socket closed"); };
#                ws.onopen    = function() {
#                    debug("connected, sending 'world' command...");
#                    ws.send(JSON.stringify({
#                        command:'world'}));
#                };
#
#                $('#submit').click(function()
#                {
#                    var nick = $('#nick').val();
#                    var msg = $('#message').val();
#                    ws.send(JSON.stringify({
#                        command:'chat',
#                        nickname:nickname,
#                        message:msg}));
#                    return false;
#                });
#
#            });
#        </script>
#      </head>
#      <body>
#        <form>
#          <label>Nick</label>
#          <input type='text' autofocus='true' id='nick' name='nick' value='anon' size='20' /><br />
#
#          <label>Message</label>
#          <input type='text' autofocus='true' id='message' name='message' value='' size='80' />&nbsp;
#          <input type='submit' id='submit' />
#        </form>
#
#        <div id="debug"></div>
#        <div id="msg"></div>
#      </body>
#  </html>
#HTML
#    end
#
#    def handle_websocket(sock)
#      # remember this...?
#      #$registry ||= {}
#      #$registry[sock.headers['Sec-WebSocket-Key']] = sock
#      sock << "Hello everyone in websocket land: #{World.current.state.value}!"
#      #p sock
#      #sock.close
#
#      puts "--- attempting to set on messsage....?"
#      sock.on_message do |env, msg|
#        puts "==== GOT A MSG: #{msg}"
#      end
#      puts "--- ok..?"
#    end
#
#
#
#    #def on_message(msg)
#    #  puts "--- got a websocket message? #{msg} (?!)"
#    #end
#
#    #def on_error(env,args)
#    #  puts "--- got.. something... ERROR?!"
#    #end
#
#  end
#end

#Ontology::WorldServer.run


#require 'rubygems'
#require 'bundler/setup'
#
#require 'ostruct'
#require "active_support/core_ext"
##require 'goliath'
##require 'eventmachine'
##require 'socket'
#require 'em-websocket'
#
## for apis/websockets
##require 'goliath'
##require 'goliath/websocket'
##require 'goliath/rack/templates'
#
#require 'ontology/version'
#require 'ontology/util/blank_slate'
#require 'ontology/util/rpc'
#
## high-level architetural structure
## (here for organizational purposes and so we can shorthand in defs)
#module Ontology
#  # states, models, simulations
#  module Core end
#
#  # tools for tracking game worlds, players, maps, etc
#  module Game end
#
#  # streaming API for accessing details about the world
#  module API end
#end
#
#require 'ontology/game/world'
#require 'ontology/game/world_server'
#require 'ontology/api/request_handler'
#require 'ontology/api/world_client'
#require 'ontology/api/async_world_client'
#
## probably shouldn't require this here...
##require 'ontology/core/driver'
#
#
##class World
##  attr_reader :value
##
##  def initialize
##    @value = 0
##  end
##
##  def step!
##    puts "=== world step! (#@value)"
##    @value = @value + 1
##  end
##
##  def to_hash
##    { :value => @value }
##  end
##end
##
##$world = World.new
##
##module WorldServer
##  include EM::P::ObjectProtocol
##  def post_init
##    @obj = $world
##  end
##
##  def receive_object(method)
##    send_object @obj.__send__(*method)
##  end
##
##  def unbind
##    @obj = nil
##  end
##end
##
##EM.run{
##  FileUtils.rm '/tmp/world.sock' if File.exists? '/tmp/world.sock'
##  EM.start_server '/tmp/world.sock', WorldServer
##  EM.add_periodic_timer(1) { $world.step! }
##
##  # use a thread because the client is blocking
##  #Thread.new{
##  #  o = RPCClient.new
##  #  o[1] = :a
##  #  o[2] = :b
##  #  o[3] = :c
##  #  p o.keys
##  #  p o.values
##  #}
##  #
##  #o = AsyncRPCClient.new
##  #o[:A] = 99
##  #o[:B] = 98
##  #o[:C] = 97
##  #o.keys{ |keys| p(keys) }
##  #o.values{ |vals| p(vals) }
##  puts "==== ONTOLOGY SERVER RUNNING"
##}
##
#
##require "ontology/version"
###require 'goliath'
##require 'eventmachine'
##require 'drb'
##
###require "ontology/world"
###require "ontology/model"
###require "ontology/actor"
###require "ontology/controller"
##
###module Ontology
###  # Your code goes here...
###  def receive_data(data)
###    p data
###  end
###end
###
###EventMachine.connect '127.0.0.1', 6666, Ontology
##
##interrupted = false
##
##trap("INT") {
##  puts "--- interrupted..."
##  interrupted = true
##}
##
##EventMachine.run {
##  EventMachine.add_periodic_timer(1) {
##    world.step!
##    if interrupted
##      puts "--- bye!"
##      DRb.stop_service
##      exit
##    end
##  }
##
##
##  DRb.start_service 'druby://:9000', world
##  puts "--- ontology server running at #{DRb.uri}"
##
##
##  # safe with event machine?
##  puts "--- joining thread... :( ?"
##  #DRb.thread.join
##}
