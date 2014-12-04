require 'rubygems'
require 'mongo'
require 'java'
require './lib/jars/mongo-2.10.1.jar'

java_import 'com.mongodb.MongoClient' do |pkg, cls|
  'JMongoClient'
end

java_import 'com.mongodb.DB' do |pkg, cls|
  'JDB'
end

class MongoHelper
  include Mongo

  def self.get_ruby_client
    MongoClient.new($application_properties['mongo_connect'], $application_properties['mongo_port'].to_i)
  end

  def self.get_java_client
    JMongoClient.new($application_properties['mongo_connect'], $application_properties['mongo_port'].to_i)
  end

  def self.test_connection
    begin
      client = get_java_client
      db = client.getDB("test")
      db.getCollectionNames()
      return true
    rescue => ex
      $logger.error("Could not log onto to Mongo with " + $application_properties['mongo_connect'] + " on port " +  $application_properties['mongo_port'].to_i)
      $logger.error(ex.to_s)
      return false
    end
  end

end


#mongo_client = MongoClient.new("vahdrtvapp05.aac.va.gov", 7012)

##mongo_client.database_names.each {|name| puts name.to_s}
##mongo_client.database_info.each { |info| puts info.inspect }
#
#db = mongo_client.db("shamu")
#coll = db["shamuCollection"]
#doc = coll.find("Cris" => "is cool!")
#puts doc.count.to_s
#doc.each {|d| puts d.to_s}
#db.collection_names.each {|name| puts "Collection name: #{name}"}
##puts doc.methods.inspect
##doc.each_pair {|key,value| puts "#{key} --> #{value}"}
##doc.keys.each {|key| puts "#{key} -> " + doc[key].to_s}
##doc = {"Cris" =>"is cool!", "Greg" => "is awesome!"}
##id = coll.insert(doc)
