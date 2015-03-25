//load("c:/m_vamu/PSTDashboard/jobs/mongo_samples/das_audit_lib.js")
//auditData("localhost","27017","das","audit",500)
function getStatus() {
    var time = new Date(new Date());
   // var time = new Date(new Date() - 1000*60*60*24*3);
    var seconds = time.getSeconds();
    var minute = time.getMinutes();

    var doc = {"DAS_STATUS": "GOOD", "audit_date" : time};

    if (minute % 2 == 0) {
        if ((seconds > 30) && seconds < 40) {
            doc = {"DAS_STATUS": "BAD",  "audit_date" : time};
        }
    }
    return doc;
}

function insertStatus(status, collection) {
    result = collection.insert(status);
    print(result + " -- " + JSON.stringify(status));
    sleep(3000);
}

function fetchDatabase(host, port, database) {
    //port is usually 27017
    conn = new Mongo(host + ":" + port);
    db = conn.getDB(database);
    return db;
}

function auditData(host, port, database, collection_name, iterations) {
    db = fetchDatabase(host, port, database);
    collection = db[collection_name];
    for (i = 0; i < iterations; i++) {
        status = getStatus();
        insertStatus(status,collection);
    }
}