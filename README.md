# Ontology

The idea is to provide a simple platform for generating and simulating ongoing virtual "worlds" and expose an API for accessing/manipulating them. Additionally, if it's running locally you should be able to connect through a local UNIX socket to do RPC on the world being simulated…

# Thoughts
So how to accomplish this?

We've got a running simulation of a world in one process. It needs to be able to:
	- expose mutable state to 'machine-local' clients (web socket server, web/app servers) [distributed ruby] 
 - publish/expose a running stream of events (could live on top of the 'state' exposure, adding events as things are changed/modified…])

We also have a web socket server that exposes the worlds. It makes sense to me to have this process also manage game 'rooms' and 'chat' and so on. 
- Gets users logged-in, connected to a world
- Pushes updates about the world to clients… (?)

It would be nice ultimately to have the Rails app 'wrap around' the web socket service, providing some of the auth and identification stuff. We'll both need to be talking to a DB…

# Architecture

(client)
- html5 canvas
- coffeescript
- game client (web sockets)

(web/app server)
- auth
- 'arcade' (wrapper around game server)
- db access api

(game server)
- lobby
- game server
- world server

# About
# Goals and Motivations
 

## Installation

Add this line to your application's Gemfile:

    gem 'ontology'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ontology

## Usage

The API I'm thinking about would basically expose a streaming endpoint that clients could connect to over web sockets.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
