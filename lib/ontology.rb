# require 'ostruct'
require 'net/http'
require 'json'

require 'celluloid'
require 'goliath'
require 'goliath/websocket'
require 'data_mapper'
require 'dm-serializer/to_json'
require 'active_support/inflector'
require 'active_support/core_ext/hash/deep_merge'

require 'minotaur'

require 'ontology/version'
require 'ontology/firehose_publisher'
require 'ontology/player'
require 'ontology/enemy'
require 'ontology/event'
require 'ontology/game_map'
require 'ontology/world'

