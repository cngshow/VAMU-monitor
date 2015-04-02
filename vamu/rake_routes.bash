#!/bin/bash
#vamu_rake_routes.bash
current_dir=`pwd`
export RUNNER_TASK=true
cd $RAILS_ROOT && $JAVA_HOME/bin/java -jar $JRUBY_COMPLETE_JAR $GEM_HOME/bin/rake routes
cd $current_dir
unset RUNNER_TASK
