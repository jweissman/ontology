# i would think chat can be a subclass of event -- we'd a nice log
class Event
  include FirehosePublisher
  include DataMapper::Resource

  property :id, String, key: true, :default => lambda { |_,_| SecureRandom.uuid }

  property :name, String, :default => 'Hello!'
  property :kind, Enum[ :damage, :attack_failed ] # :heal, :level_up, :points ]
  property :description, String

  property :details, Json, :default => {something: 'happened'}.to_json

  belongs_to :world

  # only worlds have events
  def collection_stream
    "/world/#{world.id}/events.json"
  end

  def collection_snapshot
    world.events.map(&:snapshot).to_json
  end

  def self.damage(world, source, target, amount)
    Event.new(
      world: world,
      kind: :damage,
      name: "#{source.name} dealt #{amount} damage",
      description: "#{target.name} took #{amount} damage from #{source.name}!",
      details: { target: target.position, source: source.position, amount: amount }
    )
  end
end
