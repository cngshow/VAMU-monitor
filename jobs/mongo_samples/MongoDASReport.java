package gov.va.vamu.mongo;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.UnknownHostException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.TreeMap;

import com.mongodb.BasicDBObject;
import com.mongodb.DB;
import com.mongodb.DBCollection;
import com.mongodb.DBCursor;
import com.mongodb.MongoClient;
import com.mongodb.MongoException;

public class MongoDASReport {



	private Date startDate;
	private Date endDate;
	private Map<String,Map<String,Integer>> stats = new TreeMap<String,Map<String,Integer>>();

	public String doWork(String[] args) {
		try {
			String hostname = args[0];
			String port = args[1];
			String database = args[2];
			String collection = args[3];
			startDate = new Date(Long.parseLong(args[4])*1000);
			endDate = new Date(Long.parseLong(args[5])*1000);

			StringBuilder result = new StringBuilder();
			try {
			  DBCollection col = fetchCollection(hostname,port,database,collection);
			  buildReport(col,result);
			} catch (IOException | MongoException e) {
				result.append("Failed to connect to MongoDB!\n");
				result.append("Error: " + e.toString());
			}
			return result.toString();
		} catch (Exception e) {
			// TODO Auto-generated catch block
			StringWriter sw = new StringWriter();
			PrintWriter pw = new PrintWriter(sw);
			e.printStackTrace(pw);
			return sw.toString();
		}
	//	return "Hello Cris";
	}

	private void buildReport(DBCollection col, StringBuilder result) {
		//{"DAS STATUS":"GOOD","audit_date":"2014-06-15T19:39:16.062Z"}
		DBCursor cursor = col.find(new BasicDBObject("audit_date", (new BasicDBObject("$lt", endDate)).append("$gt", startDate)));
		try{
			while (cursor.hasNext()) {
				BasicDBObject doc = (BasicDBObject)cursor.next();
				String status = doc.getString("DAS_STATUS");
				String auditDate =  (new SimpleDateFormat("yyyyMMdd")).format((doc.getDate("audit_date")));
				if (!stats.containsKey(auditDate)) {
					stats.put(auditDate, new HashMap<String, Integer>());
					stats.get(auditDate).put("GOOD", 0);
					stats.get(auditDate).put("BAD", 0);
				}
				int count = 0;
				try {
					count = (Integer)stats.get(auditDate).get(status);
				} catch (Exception e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
				count++;
				stats.get(auditDate).put(status,count);
			}
		} finally {
			cursor.close();
		}
		result.append("<table><tr><th>AUDIT DATE</th><th>GOOD GUY COUNT</th><th>EVIL BAD GUY COUNT</th></tr>\n");
		for (String date : stats.keySet()) {
			Map<String,Integer> counts = stats.get(date);
			result.append("<tr><td> " + date +"</td>\n");
			result.append("<td align=\"right\">" + counts.get("GOOD") + "</td>\n");
			result.append("<td align=\"right\">" + counts.get("BAD") + "</td></tr>\n");
		}
		result.append("</table>");
		//int c = col.find(new BasicDBObject("audit_date", (new BasicDBObject("$lt", endDate)).append("$gt", startDate))).count();
		//System.out.println("The count is " + c);
	}

	private DBCollection fetchCollection(String host, String port, String database, String collection) throws UnknownHostException {
		MongoClient client = new MongoClient(host, Integer.parseInt(port));
		DB md = client.getDB(database);
		return md.getCollection(collection);
	}

	public static void main (String[] args) {
		System.out.println("FROM MAIN:");
		System.out.println((new MongoDASReport()).doWork(args));
	}

}
