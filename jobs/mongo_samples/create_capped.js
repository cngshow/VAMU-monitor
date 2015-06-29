//sample invocation:
//c:\mongoDB-3.1\bin\mongo.exe --nodb --eval "var host='localhost',port=27017,database='das',collection_name='real_time_data',size=16384,max_documents=180;" ./jobs/mongo_samples/create_capped.js
// /usr/bin/mongo --nodb --eval "var host='localhost',port=27017,database='das',collection_name='real_time_data',size=16384,max_documents=180;" ./jobs/mongo_samples/create_capped.js

load("./jobs/mongo_samples/capped_collection.js")
createCappedCollection(host,port,database,collection_name,size,max_documents);