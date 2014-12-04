#db.system.profile.find({},{ns:1, ts:1, millis:1}).sort({millis:1}).limit(10)
#db.setProfilingLevel(0,2)

require 'java'
require './jobs/lib/mongo-java-driver-2.10.1.jar'

java_import 'com.mongodb.MongoClient' do |pkg, cls|
  'JMongoClient'
end

java_import 'com.mongodb.BasicDBObject' do |pkg, cls|
  'JBasicDBObject'
end


begin

  host_s = ARGV.shift
  port_i = ARGV.shift.to_i
  database_s = ARGV.shift
  collection_s = ARGV.shift
  limit = ARGV.shift.to_i
  start_date = Time.at(ARGV.shift.to_i)
  end_date = Time.at(ARGV.shift.to_i)

  client = JMongoClient.new(host_s,port_i);
  db = client.getDB(database_s);
  col = db.getCollection(collection_s)

  cursor = col.find(JBasicDBObject.new("ts", JBasicDBObject.new("$lt", end_date).append("$gt", start_date)),
                    JBasicDBObject.new("query", 1).
                        append("millis", 1).
                        append("ns", 1).
                        append("op", 1)).
      sort(JBasicDBObject.new("millis", -1)).
      limit(limit)
  results = "Date Range = #{start_date}  <-->  #{end_date}}\n\n\n"
  begin
    while(cursor.hasNext) do
      doc = cursor.next
      results +=doc.to_s+"\n"
    end
  ensure
    cursor.close
  end

  results
rescue => ex
  ex.backtrace.join("\n")
end
