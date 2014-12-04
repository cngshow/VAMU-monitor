load("./jobs/mongo_samples/das_audit_lib.js");

db = fetchDatabase(host,port,database);
collection = db[collection];
var start_time = new Date(start_time * 1000);
var end_time = new Date(end_time * 1000);


print("<table><tr><th>Good total:</th><th>Bad total:</th></tr>");
var cursor = collection.aggregate([
                    {$match : {audit_date : {$gte: start_time, $lte : end_time}}},
                    {$group : {_id : "$DAS_STATUS", STATUS_COUNT : {$sum : 1}}}
    ]);
var good_count;
var bad_count;
if (cursor.hasNext()) {
    while(cursor.hasNext()) {
        var doc = cursor.next();
        if(doc._id === "GOOD" ) {
            good_count = doc.STATUS_COUNT
        } else {
            bad_count = doc.STATUS_COUNT
        }
    }
} else {
    print("No results found in date range!");
}
print("<tr><td>" + good_count + "</td><td>" + bad_count + "</td></tr></table>" );
//print("start is " + start_time.toString());
//print("end is " + end_time.toString());
//print("count (for entire collection) is " + collection.count());