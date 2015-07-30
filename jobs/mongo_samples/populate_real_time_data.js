//c:\mongoDB-3.1\bin\mongo.exe --nodb --eval "var host='localhost',port=27017,database='das',audit_collection_name='audit_count',real_time_collection_name='real_time_data', lookback=10, size=16384,max_documents=180;" ./jobs/mongo_samples/populate_real_time_data.js
// /usr/bin/mongo --nodb --eval "var host='localhost',port=27017,database='das',audit_collection_name='audit_count',real_time_collection_name='real_time_data', lookback=10, size=16384,max_documents=180;" ./jobs/mongo_samples/populate_real_time_data.js



load("./jobs/mongo_samples/capped_collection.js");
//load("./capped_collection.js");

var db = fetchDatabase(host, port, database);

populateRealTimeCappedCollection(db,audit_collection_name, real_time_collection_name,lookback, size, max_documents);
