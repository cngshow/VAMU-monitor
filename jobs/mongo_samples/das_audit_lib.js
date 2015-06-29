//load("c:/m_vamu/PSTDashboard/jobs/mongo_samples/das_audit_lib.js")
//load("./jobs/mongo_samples/das_audit_lib.js")
//auditData("localhost","27017","das","audit",500)
//auditDataRandom("localhost","27017","das","audit_count",500,1,5)
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

function getCounts() {
    var time = new Date(new Date());
    var doc = {"DAS_COUNTS": Math.round(getRandomArbitrary(1,11)), "audit_date" : time};

    return doc;
}


function insertStatus(status, collection) {
    result = collection.insert(status);
    print(result + " -- " + JSON.stringify(status));
    sleep(3000);
}

function fetchDatabase(host, port, database) {
    //port is usually 27017
    var conn = new Mongo(host + ":" + port);
    var db = conn.getDB(database);
    return db;
}

// Returns a random number between min (inclusive) and max (exclusive)
function getRandomArbitrary(min, max) {
    return Math.random() * (max - min) + min;
}


function auditData(host, port, database, collection_name, iterations) {
    var db = fetchDatabase(host, port, database);
    collection = db[collection_name];
    for (i = 0; i < iterations; i++) {
        var status = getStatus();
        insertStatus(status,collection);
    }
}

function auditDataRandom(host, port, database, collection_name, iterations,min_pause, max_pause) {
    var db = fetchDatabase(host, port, database);
    createIndices(db,collection_name);
    collection = db[collection_name];
    for (i = 0; i < iterations; i++) {
        var status = getCounts();
        insertStatus(status,collection);
        sleep(1000*getRandomArbitrary(min_pause,max_pause))
    }

    function createIndices(db,collection_name) {
        db.collection_name.createIndex({audit_date:1});
    }
}