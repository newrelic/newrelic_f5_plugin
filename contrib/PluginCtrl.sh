#!/bin/sh
#
# chkconfig: 2345 90 10
# description: Starts and stops the New Relic Plugin

# Source function library.
if [ -f /etc/rc.d/functions ];
then
    . /etc/init.d/functions
fi

# PluginCtrl.sh
# Control script for running the New Relic Plugin
# as a Unix service via an easy-to-use command line interface  
#
# Usage:
# PluginCtrl.sh start
# PluginCtrl.sh stop
# PluginCtrl.sh status
# PluginCtrl.sh help
#
# The exit codes returned are:
#	0 - operation completed successfully
#	2 - usage error
#	3 - Plugin could not be started
#	4 - Plugin could not be stopped
#	8 - configuration syntax error
#
# When multiple arguments are given, only the error from the last one is reported.
#
# Run "PluginCtrl.sh help" for usage info

######### START OF CONFIGURATION SECTION
######### SET VARIABLES AS APPROPRIATE

# Set the path to the root of your NewRelic install:
PLUGIN_HOME=/tmp/newrelic
CONFIG_FILE=${PLUGIN_HOME}/config/newrelic_plugin.yml

# Define the executable used to run the Plugin here. The path is relative to PLUGIN_HOME.
PLUGIN_CMD=f5_monitor
PLUGIN_ARGS="run -c ${CONFIG_FILE}"

######### END OF CONFIGURATION SECTION 
######### DO NOT EDIT BELOW THIS LINE

export PLUGIN_HOME
export PLUGIN_JAR
PLUGIN_PARENT=${PLUGIN_HOME}

if [ -z "$PLUGIN_HOME" ]; then
	PLUGIN_HOME="`pwd`/.."; export PLUGIN_HOME
fi
cd "${PLUGIN_HOME}"
cd .
PLUGIN_PARENT="`pwd`"; export PLUGIN_PARENT
cd "${PLUGIN_HOME}"					

# The PLUGIN_LOGFILE
PLUGIN_LOGFILE="${PLUGIN_HOME}/plugin.log"

# the path to your PID file
PLUGIN_PIDFILE="${PLUGIN_HOME}/plugin.pid"

# the full command to be executed (command + args) 
PLUGIN_FULL_CMD="${PLUGIN_CMD} ${PLUGIN_ARGS}"

cd "${PLUGIN_HOME}"

ERROR=0
ARGV="$@"
if [ "x$ARGV" = "x" ] ; then 
    ARGS="help"
fi

for ARG in $@ $ARGS
do
#
# 1. Check whether PID file is available / not ?
#	 if true	--> check whether the PID stored in the PID file is running / not ?
#					if true --> set the flags [PROCESS_RUNNING, PID_STATUS] and break
# 					else	--> remove the PID file, unset the flag [PID_STATUS] and call 'check_plugin_status'
#	 else		-->	unset the flag [PID_STATUS] and call 'check_plugin_status'						
#
# 2. In 'check_plugin_status' 
#	 check if any process has the path of the plugin executible / not ?
#	 if true	--> write that PID into the PID file and set the flag [PROCESS_RUNNING]
# 	 else		--> unset the flag [PROCESS_RUNNING]

# Check whether the Plugin is running or not
check_plugin_status(){
	PID_FLAG=-1
	PID_FLAG="`ps -Aeo pid,args | grep ${PLUGIN_CMD} | grep -v grep | sed 's/^[ \t]*//' | cut -d' ' -f1`"	
	if [ ${PID_FLAG:- -1} -gt -1 ]; then	
		PID=$PID_FLAG			
		echo "$PID" > "$PLUGIN_PIDFILE"			
		PROCESS_RUNNING=1			
	else
		PROCESS_RUNNING=0
		PID_FLAG=-1
	fi	
}

#
# Check whether PID file is available / not ?
#
if [ -f "$PLUGIN_PIDFILE" ] ; then
	PID=`cat "$PLUGIN_PIDFILE"`
	if [ "x$PID" != "x" ] && kill -0 $PID 2>/dev/null ; then	
		STATUS="Plugin (pid $PID) running"
		PID_STATUS=1
		PROCESS_RUNNING=1
	else
		STATUS="Plugin (pid $PID?) not running"	  
		rm "$PLUGIN_PIDFILE"		
		PID_STATUS=0
		check_plugin_status
fi
else
	STATUS="Plugin (no pid file) not running"	
	PID_STATUS=0	
	check_plugin_status
fi
	
case $ARG in
	
start)
	if [ "$PROCESS_RUNNING" -eq 1 ]; then
	    echo "$0 $ARG: Plugin (pid $PID) already running"
	    continue
	fi	
	if [ "$PID_STATUS" -eq 0 ]; then
		nohup $PLUGIN_FULL_CMD >> $PLUGIN_LOGFILE 2>&1 &
		if [ "x$!" != "x" ] ; then
	    	echo "$0 $ARG: Starting Plugin..."
	    	check_plugin_status
	    	if [ $PROCESS_RUNNING -eq 0 ]; then
				echo "$0 $ARG: Plugin is NOT running."
			else
				echo "$0 $ARG: Plugin is running."
			fi
			echo "Please check log file for more details."
		else
	    	echo "$0 $ARG: Plugin could not be started."
	    	ERROR=3
		fi
	fi
	;;
	
stop)
	if [ "$PROCESS_RUNNING" -eq 0 ]; then
		    echo "$0 $ARG: $STATUS"
			
	    continue
	fi
	if kill $PID ; then
		echo "$0 $ARG: Stopping Plugin..."
			while [ "${?}" -eq 0 ]		# Repeat until the Plugin process has terminated
			do	
				ps -p $PID >/dev/null	# Check if the Plugin process has terminated
			done		
		rm "$PLUGIN_PIDFILE"
	    echo "$0 $ARG: Plugin stopped"		
	else
	    echo "$0 $ARG: Plugin (pid $PID) could not be stopped"
	    ERROR=4
	fi
	;; 
		
status)
    	if [ "$PROCESS_RUNNING" -eq 1 ]; then
    		echo "$0 $ARG: Plugin (pid $PID) is running"
    	else
    		echo "$0 $ARG: Plugin stopped"			
    	fi
    	;;  
    
	*)
	echo "usage: $0 (start|stop|status|help)"
	cat <<EOF

status     - status of the Plugin
start      - start Plugin
stop       - stop Plugin
help       - this screen

EOF
	ERROR=2
    ;;
esac
done
exit $ERROR