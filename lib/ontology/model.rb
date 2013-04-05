class Model
  include ActiveModel::Validations
  include ActiveModel::Serialization

  def initialize
    register self
  end

  class << self
    def model_name
      self.class.to_s.downcase
    end

    def _registry
      @registry ||= {}
    end

    def register(model)
      model.id = UUID.new
      _registry[model.id] << self
    end

    def all
      _registry.values
    end

    def exists?(id)
      _registry.has_key?(id)
    end

    def find(id)
      raise "Could not find #{model_name} with id #{id}" unless _registry.has_key?(id)
      _registry[id]
    end

    def delete(id)
      raise "Could not find #{model_name} with id #{id}" unless _registry.has_key?(id)
      _registry[id] = nil
    end

    def destroy_all(id)
      _registry = {}
    end
  end
end
