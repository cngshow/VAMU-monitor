require 'mongoid'

module MongoJobConnector
  def initialize_mongo(environment)
    environments = [:development, :test, :production]
    raise ArgumentError, "The symbol :development, :test, or :prioduction must be given!" unless environments.include?(environment)
    Mongoid.load!("./config/mongoid.yml", environment)
  end

  def get_session(session)
    Mongoid::Sessions::Factory.create(session)
  end

  alias :get_db :get_session

  def disconnect_all
    Mongoid::Sessions.disconnect
  end
end
