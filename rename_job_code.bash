source shamu_env.bash
java -jar ./lib/jars/jruby-complete-1.7.11.jar ./script/rails r -e $1 "JobLogEntry.rename_job_code('$2','$3')"
