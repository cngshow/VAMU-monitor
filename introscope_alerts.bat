@ECHO OFF
java -jar %JRUBY_COMPLETE_JAR% ./script/rails r -e %1 "JobLogEntry.introscope_alerts"
