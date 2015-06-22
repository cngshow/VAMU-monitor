#!/bin/bash
#vamu_deployment.bash
#source $RAILS_ROOT/vamu/rails_gems_jruby.bash
$JAVA_HOME/bin/java -server -XX:MaxPermSize=1024M -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -XX:+HeapDumpOnOutOfMemoryError -Xmx1024m -Xms256m -jar $JRUBY_COMPLETE_JAR $GEM_HOME/bin/trinidad
