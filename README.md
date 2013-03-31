# Ontology

The idea is to provide a simple platform for generating and simulating ongoing virtual "worlds" and expose an API for accessing/manipulating them. Additionally, if it's running locally you should be able to connect through a local UNIX socket to do RPC on the world being simulated.

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
