load("./das_audit_lib.js")

function createCappedCollection(host, port, database, capped_name, size, max_records) {
    var db = fetchDatabase(host, port, database);
    //size = parseInt(size)
    //max_records = parseInt(max_records)
    print("Creating a capped collection...");
    db.createCollection(capped_name,{capped:true, size: size, max: max_records});
}

function populateRealTimeCappedCollection(db,audit_collection_name, real_time_collection_name, lookback, size, max_documents) {
    db[real_time_collection_name].drop();
    db.createCollection(audit_collection_name,{capped:true, size: size, max: max_documents});
    var end_time = new Date();
    var start_time = new Date(end_time.getTime() - lookback*1000);
    var doc = null;

    while (true) {
        var cursor = db[audit_collection_name].aggregate([
            {$match:{audit_date:{$gte : start_time, $lte : end_time}}},
            {$group:{_id:end_time.getTime(), "Total_Count":{$sum:"$DAS_COUNTS"}}}
        ]);
        if (cursor.hasNext()) {
            doc = cursor.next();
        } else {
            doc = new Object();
            doc['_id'] = end_time.getTime();
            doc['Total_Count'] = 0;
            print("no document found - inserting zero");
        }
        doc['start_time_epoch'] = start_time.getTime();
        doc['end_time_epoch'] = end_time.getTime();
        db[real_time_collection_name].insert(doc);

        print("Inserted " + new Date() + " -- "  +  JSON.stringify(doc));
        sleep(lookback*1000);
        start_time = new Date(end_time.getTime() + 1);
        end_time = new Date();
    }
}
