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

  def collection_snapshot
    self.class.all.map(&:snapshot).to_json
  end

  def collection_sync
    #puts "--- firehose sync has this for the #{model_name} collection: #{self.class.all.inspect}"
    firehose collection_stream, collection_snapshot
  end

  def sync
    #puts "--- firehose sync has this for the current #{model_name} instance: #{snapshot.to_json}"
    firehose
  end

  protected
  def firehose(endpoint=instance_stream, payload=snapshot.to_json)
    begin
      #puts "--- publishing update to #{endpoint}: #{payload.inspect}"
      req = Net::HTTP::Put.new endpoint
      req.body = payload
      Net::HTTP.start('127.0.0.1', 7474).request(req)
    rescue => err
      #puts "--- there was a problem talking to firehose :/"
      #puts err
    end
  end
end
