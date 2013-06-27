#!/bin/sh
#
# JBoss Control Script
#
### BEGIN INIT INFO
# Provides: jbossas
# Required-Start: $network $syslog
# Required-Stop: $network $syslog
# Default-Start:
# Default-Stop:
# Description: JBoss J2EE Server
# Short-Description: start and stop jbossas
### END INIT INFO
# chkconfig: - 80 20
# description: JBoss J2EE Server
#

### enhanced by systal 01182012 ###
# combined rpm control script and basic control script
# intended for non-clustered instances
# features
# - will resort to hard kill (only if necessary) for stop function and find/kill any orphaned processes (based on my extensive research of java shutdown signals on impaired environments which can be found here)
# - check for existing process before starting
# - ability to create thread dumps
# - clear cache on stops
# - does not utilize lock files as this would complicate our granular acl permissions
# limitations
# - not for clustered jboss instances
# - not for rpm installations
# - jboss user must have shell enabled, always runs as this user instead of root
# - offers limited prerequisite folder/file creation or ownership/permissions
# - does not configure any JAVA_OPTS (these should be kept separate in my opinion)
# TODO:
# - include clustering variables and JAVA_OPTS additions
# - create variable for dump count, calculate wait time based on variables
# - utilize lock file?
# follow return code standards: page 393-394 of http://standards.iso.org/ittf/PubliclyAvailableStandards/c043781_ISOIEC%2023360-1%3B2006%28E%29.zip or from /etc/init.d/functions, the codes should be:
# 0: running
# 1: dead but pid file exists
# 2: dead but subsys locked
# 3: stopped
# 4: unknown

# Source function library.
if [ -r /etc/rc.d/init.d/functions ]; then
  . /etc/rc.d/init.d/functions
fi

NAME=`basename $0`
# define where jboss is - this is the directory containing directories log, bin, conf etc
JBOSS_HOME=${JBOSS_HOME:-"/usr/local/jboss/jboss-as"}

# define the user under which jboss will run, or use 'RUNASIS' to run as the current user
if [ `whoami` = "jboss" ]; then
	JBOSS_USER=${JBOSS_USER:-"RUNASIS"}
else
	JBOSS_USER=${JBOSS_USER:-"jboss"}
fi

if [ "$JBOSS_USER" = "RUNASIS" ]; then
	SUBIT=""
else
	SUBIT="su - $JBOSS_USER -c "
fi

# make sure java is in your path
JAVAPTH=${JAVAPTH:-"/usr/lib/jvm/java"}

# define thread dump location
DUMPFOLDER=${DUMPFOLDER:-"jbossdump_$(date +%m%d%Y-%H%M)"}
DUMPWAITTIME=${DUMPWAITTIME:-"60"}
MAXDUMPDAYS=${MAXDUMPDAYS:="30"}

# configuration to use, usually one of 'minimal', 'default', 'all', 'production'
JBOSS_CONF=${JBOSS_CONF:-"default"}

# if JBOSS_HOST specified, use -b to bind jboss services to that address
JBOSS_HOST=$(hostname)
JBOSS_BIND_ADDR=${JBOSS_HOST:+"-b $JBOSS_HOST"}

# define the script to use to start jboss
JBOSSSH=${JBOSSSH:-"$JBOSS_HOME/bin/run.sh -c $JBOSS_CONF $JBOSS_BIND_ADDR -Djboss.server.log.threshold=WARN"}

# define the timeout period for starting the server
JBOSS_START_TIMEOUT=${JBOSS_START_TIMEOUT:-"240"}

# define the timeout period for stopping the server
JBOSS_STOP_TIMEOUT=${JBOSS_STOP_TIMEOUT:-"180"}

# define what will be done with the console log
# JBOSS_CONSOLE=${JBOSS_CONSOLE:-"/dev/null"}
JBOSS_CONSOLE=${JBOSS_CONSOLE:-"$JBOSS_HOME/server/$JBOSS_CONF/log/console.log"}

# ensure the console log file exists
if [ -n "$JBOSS_CONSOLE" -a ! -d "$JBOSS_CONSOLE" ]; then
	if [ -z "$SUBIT" ]; then
		/bin/touch $JBOSS_CONSOLE
	else
		$SUBIT "/bin/touch $JBOSS_CONSOLE"
	fi
fi

CMD_START="cd $JBOSS_HOME/bin; $JBOSSSH"

if [ -z "`echo $PATH | grep $JAVAPTH`" ]; then
	export PATH=$PATH:$JAVAPTH
fi

if [ ! -d "$JBOSS_HOME" ]; then
	echo JBOSS_HOME does not exist as a valid directory : $JBOSS_HOME
	exit 1
fi
if [ ! -d "$JBOSS_HOME"/server/"$JBOSS_CONF" ]; then
	echo JBOSS_CONF does not exist as a valid directory : $JBOSS_HOME/server/$JBOSS_CONF
	exit 1
fi

# echo CMD_START = $CMD_START

RETVAL=0

function procrunning()
{
	procid=0
	JBOSSSCRIPT=$(echo $JBOSSSH | awk '{print $1}')
	for procid in `/sbin/pidof -x "$JBOSSSCRIPT"`; do
		ps -fp $procid | grep "${JBOSSSH% *}" > /dev/null && pid=$procid
	done
}
childprocrunning()
{
	# use this function to grab java child process ids (for thread dumps or cleaning up orphaned processes)
	procid=0
	JBOSSSCRIPT=$(echo $JBOSSSH | sed 's/run.sh/run.jar/' | awk '{print $1}')
	procid=`ps -ef | grep "${JBOSSSCRIPT% *}" | grep -v grep | awk '{print $2}'` > /dev/null && pid=$procid

}

start()
{
	echo -n $"Starting ${NAME}: "

	pid=0
	procrunning
	if [ ! $pid == '0' ]; then
		failure $"${NAME} startup"
		echo -n -e "\nProcess already running with PID $pid"
		echo -n -e "\n"
		return 0
fi

	# check if port 8080 is being used
	portbusy=`netstat -pntl 2> /dev/null | grep ":8080"`
	if test "x$portbusy" != x; then
		failure $"${NAME} startup"
		echo -n -e "\nPort 8080 is busy, is there a Tomcat running?"
		echo -n -e "\n"
		return 1
	fi

	for logfile in boot.log server.log; do
		if [ -f $JBOSS_HOME/server/$JBOSS_CONF/$logfile ]; then
			if [ -z "$SUBIT" ]; then
				/bin/touch $JBOSS_HOME/server/$JBOSS_CONF/$logfile
			else
				$SUBIT "/bin/touch $JBOSS_HOME/server/$JBOSS_CONF/$logfile"
			fi
		fi
	done

	cd $JBOSS_HOME/bin

	# determine userid and start jboss
	if [ -z "$SUBIT" ]; then
		eval $CMD_START > ${JBOSS_CONSOLE} 2>&1 &
	else
		$SUBIT "$CMD_START > ${JBOSS_CONSOLE} 2>&1 &"
	fi

	sleep=0
	RETVAL=1
	while [ $sleep -lt $JBOSS_START_TIMEOUT -a $RETVAL -eq 1 ]; do
		echo -n -e "\nwaiting for processes to start";
		sleep 10
		sleep=`expr $sleep + 10`
		pid=0
		procrunning
		if [ $pid == '0' ]; then
			failure $"${NAME} startup"
			echo -n -e "\nProcess crashed on startup"
			echo
			RETVAL=3
		else
			RETVAL=0
		fi
	done
	
	if [ -r /etc/rc.d/init.d/functions ]; then
		if [ $RETVAL -eq 0 ]; then
			success $"${NAME} startup"
		else
			# check if the process is still running
			pid=0
			procrunning
			if [ $pid != '0' ]; then
				echo -n -e "\n${NAME} startup has timed out, but process is still running with PID $pid\n"
				echo
			else
				failure $"${NAME} startup"
			fi
		fi
	fi

	echo
	[ $RETVAL = 0 ]
	return $RETVAL
}
stop()
{
	echo -n $"Stopping ${NAME}: "
	pid=0
	procrunning
	if [ $pid == '0' ] ; then
		failure $"${NAME} shutdown"
		echo -n -e "\nNo ${NAME} is currently running\n"
		return 3
	fi
	
	pid=0
	RETVAL=1
	procrunning

	# First, try to kill it nicely
# https://docs.google.com/spreadsheet/ccc?key=0AiZ3fCT4e0KLdDMtVXZPR3p5ZmhBemNGTWl1d1ptbUE
	if [ $RETVAL != 0 ] ; then
		for id in `ps --ppid $pid | awk '{print $1}' | grep -v "^PID$"`; do
			if [ -z "$SUBIT" ]; then
				# /bin/kill -1 $id
				# /bin/kill -2 $id
				/bin/kill -15 $id
				# /bin/bash $JBOSS_HOME/bin/shutdown.sh -s jnp://$JBOSS_HOST:1099
			else
				# $SUBIT "/bin/kill -1 $id"
				# $SUBIT "/bin/kill -2 $id"
				$SUBIT "/bin/kill -15 $id"
				# $SUBIT "/bin/bash $JBOSS_HOME/bin/shutdown.sh -s jnp://$JBOSS_HOST:1099"
			fi
		done
		sleep=0
		while [ $sleep -lt $JBOSS_STOP_TIMEOUT -a $RETVAL -eq 1 ]; do
			echo -n -e "\nwaiting for processes to stop"
			sleep 10
			sleep=`expr $sleep + 10`
			pid=0
			procrunning
			if [ $pid == '0' ]; then
				RETVAL=0
			fi
		done
	fi

	# Still not dead... notify user

	count=0
	pid=0
	procrunning

	if [ $pid != '0' ] ; then
		echo -n -e "\njbossas is still running. resorting to a hard kill"
		if [ -z "$SUBIT" ]; then
			/bin/kill -9 ${pid}
		else
			$SUBIT "/bin/kill -9 ${pid}"
		fi
		procrunning
		if [ ! $pid='0' ] ; then
			# this point should never be reached as a parent process should always be able to be killed
			echo -e "\nTimeout: hard kill was sent, but process is still running with PID $pid"
			failure $"${NAME} shutdown"
			RETVAL=1
		else
			# before declaring victory, check for and kill any orphaned child process first
			pid=0
			childprocrunning
			if [ ! $pid = '0' ] ; then
				echo -n -e "\nhard killing remaining orphan child process (pid $pid)\n"
				if [ -z "$SUBIT" ]; then
					/bin/kill -9 ${pid}
				else
					$SUBIT "/bin/kill -9 ${pid}"
				fi
			else
				if [ -r /etc/rc.d/init.d/functions ]; then
					echo
					success $"${NAME} shutdown"
				fi
				RETVAL=0
			fi
		fi
	else
		if [ -r /etc/rc.d/init.d/functions ]; then
			echo
			success $"${NAME} shutdown"
		fi
		RETVAL=0
	fi
	clearcache
	echo
	[ $RETVAL -eq 0 ]
	return $RETVAL
}
clearcache()
{
	echo -e -n "clearing cache..."
	find -L "${JBOSS_HOME}"/server/"${JBOSS_CONF}"/{data,tmp,work}/. 2> /dev/null | xargs rm -r 2> /dev/null
	# detect liferay cache
	if [ -d $JBOSS_HOME/../data/lucene/ ]; then
		find -L "${JBOSS_HOME}"/../data/lucene/. 2> /dev/null | xargs rm -r 2> /dev/null
	fi
	if [ -d $JBOSS_HOME/../data/jackrabbit/ ]; then
		find -L "${JBOSS_HOME}"/../data/jackrabbit/. 2> /dev/null | xargs rm -r 2> /dev/null
	fi
	find -L /tmp/. -user jboss 2> /dev/null | grep -v ${DUMPFOLDER} | grep -v vmware | grep -v lost+found | xargs rm -r 2> /dev/null

	return 3
}
status()
{
	pid=0
	procrunning
	if [ $pid == '0' ]; then
		echo "${NAME} is stopped";
		return 3
	else
		echo "${NAME} (pid $pid) is running...";
		return 0
	fi
}
dump()
{
	# check prerequisite: make sure that the thread dumps will go to the console
	if [ -n "$JBOSS_CONSOLE" -a ! -f "$JBOSS_CONSOLE" ]; then
		# failure $"${NAME} dump"
		echo -n -e "\nERROR: no console log found to create thread dumps: $JBOSS_CONSOLE"
		echo -n -e "\nEdit value of JBOSS_CONSOLE in /etc/init.d/jbossas and restart\n"
		return 4
	fi
	pid=0
	procrunning
	if [ $pid == '0' ] ; then
		# failure $"${NAME} dump"
		echo -n -e "\nNo JBossas is currently running\n"
		return 3
	fi

	DIR=/tmp/${DUMPFOLDER}
	mkdir $DIR
	echo -n -e "\nthread dump creation will take several minutes. started at $(date)"
	echo -n -e "\nwhen finished, files will be copied to ${DIR}, readable by developers"
	pid=0
	childprocrunning
	if [ -z "$SUBIT" ]; then
		/bin/kill -3 ${pid}; sleep ${DUMPWAITTIME};
		/bin/kill -3 ${pid}; sleep ${DUMPWAITTIME};
		/bin/kill -3 ${pid}; sleep ${DUMPWAITTIME};
		/bin/kill -3 ${pid}; sleep ${DUMPWAITTIME};
		/bin/kill -3 ${pid};
	else
		$SUBIT "/bin/kill -3 ${pid}"; sleep ${DUMPWAITTIME};
		$SUBIT "/bin/kill -3 ${pid}"; sleep ${DUMPWAITTIME};
		$SUBIT "/bin/kill -3 ${pid}"; sleep ${DUMPWAITTIME};
		$SUBIT "/bin/kill -3 ${pid}"; sleep ${DUMPWAITTIME};
		$SUBIT "/bin/kill -3 ${pid}";
	fi

	cp -a "$JBOSS_CONSOLE" "${DIR}"/{boot,console}.log
	cd $JBOSS_HOME/server/$JBOSS_CONF/log/
	for i in `find . -type f -name "*log*" -mtime -5` ; do
		cp -a $i "${DIR}"/"${i}"
	done
	chmod 775 ${DIR}
	# change ownership to root so that clearcache() does not remove the log files in the folder
	chown -R root:root ${DIR}
	# remove any old dump folders
	find /tmp/ -mindepth 1 -maxdepth 1 -type d -name "`echo ${DUMPFOLDER} | cut -d "_" -f1`_*" -mtime +${MAXDUMPDAYS} | xargs rm -r 2> /dev/null

	echo -n -e "\nprocess finished at $(date)\n"
	# success $"${NAME} dump"
	return 0
}
tattle()
{
	cd /tmp/;
	wget -nv http://norrlinuxap001.phly.net/jboss_files/jboss/tattletale.tar.gz --output-document=tattletale.tar.gz | 2> /dev/null
	if [ ! -f /tmp/tattletale.tar.gz ] ; then
		echo "unable to download tattletale.tar.gz from http://norrlinuxap001.phly.net/jboss_files/jboss/tattletale.tar.gz"
		#failure $"${NAME} tattle
		return 1
	fi

	tar -xf tattletale.tar.gz
	mv tattletale-* tattletale
	chown -HLR $JBOSS_USER:$JBOSS_USER /tmp/tattletale*
	cd /tmp/tattletale

	echo -n -e "\ntattle tale report creation will take several minutes. started at $(date)"
	echo -n -e "\nwhen finished, reports will be at /tmp/jboss-tattletale-$(date +%m%d%Y) and retrievable by developers\n"

	# check for 512 MB of free memory
	FREE=`free -m | grep buffers/cache | cut -d " " -f 16`
	if [ "${FREE}" -lt 512 ] ; then
		echo "you need at least 512 M of unused memory. this system only has ${FREE}"
		#failure $"${NAME} tattle
		return 1
	fi

	if [ -z "$SUBIT" ]; then
		java -Xmx512m -jar /tmp/tattletale/tattletale.jar `find $JBOSS_HOME/server/$JBOSS_CONF/deploy/ -mindepth 1 -maxdepth 1 | grep -i -e ".war" -i -e ".ear" | grep -v console | grep -v .xml | sort` /tmp/jboss-tattletale-$(date +%m%d%Y)
	else
		$SUBIT java -Xmx512m -jar /tmp/tattletale/tattletale.jar `find $JBOSS_HOME/server/$JBOSS_CONF/deploy/ -mindepth 1 -maxdepth 1 | grep -i -e ".war" -i -e ".ear" | grep -v console | grep -v .xml | sort` /tmp/jboss-tattletale-$(date +%m%d%Y)
	fi

	# cleanup
	rm -f /tmp/tattletale.*
	rm -rf /tmp/tattletale/
	# remove any old tattle folders
	find /tmp/ -mindepth 1 -maxdepth 1 -type d -user jboss -name "jboss-tattletale-*" -mtime +${MAXDUMPDAYS} | xargs rm -r 2> /dev/null

	echo -n -e "\nprocess finished at $(date)\n"
	# success $"${NAME} tattle"
	return 0
}

# restart only if process is already running
condrestart() {
	pid=0
	procrunning
	if [ $pid != 0 ]; then
		stop
		sleep 3
		start
	fi
}

case "$1" in
start)
	start
	;;
stop)
	stop
	;;
restart|reload)
	stop
	sleep 3
	start
	;;
condrestart)
	condrestart
	;;
status)
	status
	;;
dump)
	dump
	;;
tattle)`
	tattle
	;;
help)
	echo "usage: $0 (start|stop|status|dump|tattle|restart|help)"
	;;
*)
	echo "usage: $0 (start|stop|status|dump|tattle|restart|help)"
esac
