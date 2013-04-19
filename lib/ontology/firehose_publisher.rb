
require 'firehose'
require 'json'

# TODO think about this; we're really, really coupled to DM
module FirehosePublisher
  def model_name
    self.class.name.underscore
  end

  # TODO nested resources? (e.g.: worlds/:id/maps.json)
  # [see how players is handling it]

  def collection_stream
    "/#{model_name.pluralize}.json"
  end

  def instance_stream
    "/#{model_name}/#{id}.json"
  end

  def snapshot
    attributes
  end

  #def sync
  #  puts "--- firehose sync has this for the current #{model_name} instance: #{snapshot.to_json}"
  #  firehose
  #end

  def firehose(payload=snapshot.to_json, endpoint=instance_stream)
    puts "--- publishing update to #{endpoint}: #{payload.inspect}"
    firehose_producer.publish(payload).to endpoint

    #begin
    #  req = Net::HTTP::Put.new endpoint
    #  req.body = payload
    #  Net::HTTP.start('127.0.0.1', 7474).request(req)
    #rescue => err
    #  puts "--- there was a problem talking to firehose :/"
    #  puts err
    #end
  end

  def firehose_producer(firehose_instance="//127.0.0.1:7474")
    @firehose_producer ||= Firehose::Producer.new(firehose_instance)
  end


end
