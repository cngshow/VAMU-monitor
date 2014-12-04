load("./jobs/mongo_samples/das_audit_lib.js");
print("The host is " + host);
print("The port is " + port);
print("The database is " + database);
print("The collection is " + collection);
print("The lookback_millis is " + lookback_millis);
print("<br><br><br>");
db = fetchDatabase(host,port,database);
collection = db[collection];

var end_time = new Date();
var start_time = end_time - lookback_millis;
var start_time = new Date(start_time);

//var bad_count = db.audit.find({"$and" : [{audit_date : {"$lt" : t}},{audit_date : {"$gt" : t2}},{"DAS STATUS" : "BAD"}]}).count();
var bad_count =  db.audit.find({audit_date : {"$gt" : start_time, "$lt" : end_time},"DAS_STATUS" : "BAD"}).count();
var good_count =  db.audit.find({audit_date : {"$gt" : start_time, "$lt" : end_time},"DAS_STATUS" : "GOOD"}).count();
print("<span style=\"display: none>\"");
if (bad_count > 0) {
print("__RED_LIGHT__");
} else {
    print("__GREEN_LIGHT__");
}
print("</span>");
var color = (bad_count > 0) ? "red" : "green";
var html = "";
html += "<div style=\"border-style: double;border-color:" + color +" \">";
html += "GOOD count = " + good_count + "<br><br>";
html += "BAD count = " + bad_count + "<br><br>";
html += "Start time = " + start_time.toString() + "<br>";
html += "End time = " + end_time.toString() + "</div>";
print(html);

//print("<b>The number of records in the collection is " + collection.find().count() + "</b>");

//db.audit.find({audit_date : {"$lt" : t, "$gt" : t2}}).count()
//db.audit.find({"$and" : [{audit_date : {"$lt" : t}},{audit_date : {"$gt" : t2}}]}).count()

//> db.audit.find({"$and" : [{audit_date : {"$lt" : t}},{audit_date : {"$gt" : t2}},{"DAS STATUS" : "GOOD"}]}).count()
//20
//> db.audit.find({"$and" : [{audit_date : {"$lt" : t}},{audit_date : {"$gt" : t2}},{"DAS STATUS" : "BAD"}]}).count()
//0
//> db.audit.find({audit_date : {"$lt" : t, "$gt" : t2},"DAS STATUS" : "BAD"}).count()
//0
//> db.audit.find({audit_date : {"$lt" : t, "$gt" : t2},"DAS STATUS" : "GOOD"}).count()
//20