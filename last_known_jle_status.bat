@ECHO OFF
%java_home%\bin\java -jar %JRUBY_COMPLETE_JAR% ./script/rails r -e %1 "JobMetadata.get_last_known_status_for_jc(\"%2\",\"%3\")"