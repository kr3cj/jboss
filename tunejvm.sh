#!/bin/bash
# fail safe if JBOSS_HOME does not evaluate, exit. Otherwise commands may be applied to root directory
if [ ! -d "$JBOSS_HOME" ]; then
 echo "Exiting. JBOSS_HOME does not exist as a valid directory : $JBOSS_HOME"
 echo "Try executing the script as bash ./script.sh"
 exit 1
fi

cd $JBOSS_HOME/bin/
OUT=tunejvm_$(date +%m%d%Y-%H%M).log
(

echo "basic tuning of jvm, references:"
echo "see http://www.redhat.com/summit/2011/presentations/jbossworld/taste_of_training/friday/Raposa_JBoss_EAP5_Troubleshooting_Part_2.pdf"
echo "see google doc Java Perf Tuning and Monitoring: https://docs.google.com/Doc?docid=0ASZ3fCT4e0KLZGZkcG12c2dfNDQ4Y2puaDVzZ2Q&hl=en"
echo "see http://www.austinjug.org/presentations/JDK6PerfUpdate_Dec2009.pdf"

echo "backup and date current run.conf"
cp run.conf run.conf_$(date +%m%d%Y-%H%M).bak
echo "reset run.conf"
cp -av run.conf.bak run.conf

echo "declare all common jvm configurations to base file"
echo '
# tuning recommended for jboss5 eap/ewp
JAVA_OPTS="$JAVA_OPTS -server"
JAVA_OPTS="$JAVA_OPTS -XX:+AggressiveOpts"
JAVA_OPTS="$JAVA_OPTS -XX:+DoEscapeAnalysis"' >> $JBOSS_HOME/bin/run.conf

echo '
# utilize all cpus for garbage collection
# for high throughput (batch jobs, long transactions):"
# JAVA_OPTS="$JAVA_OPTS -XX:+UseParallelOldGC -XX:+UseParallelGC -XX:ParallelGCThreads=2"
# for low pause, high throughput (portal app):"
JAVA_OPTS="$JAVA_OPTS -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:ParallelGCThreads=2"

# troubleshooting garbage collection (make sure JVM expands variables)
# JAVA_OPTS="$JAVA_OPTS -verbose:gc -XX:+PrintGCTimeStamps -XX:+PrintGCDetails -Xloggc:$JBOSS_HOME/server/$JBOSS_CONF/log/gc`date +%m%d%Y-%H%M`.log"' >> $JBOSS_HOME/bin/run.conf

# move MaxPermSize
sed -ci 's/\ -XX:MaxPermSize=256m//g' $JBOSS_HOME/bin/run.conf
echo '# other configurations
# perm size
JAVA_OPTS="$JAVA_OPTS -XX:PermSize=128m -XX:MaxPermSize=512m"
# eden space
# JAVA_OPTS="$JAVA_OPTS -XX:NewSize=1024m -XX:MaxNewSize=1024m"
# JAVA_OPTS="$JAVA_OPTS -XX:ReservedCodeCacheSize=64m"

# troubleshooting using visualvm
# JAVA_OPTS="$JAVA_OPTS -Dcom.sun.management.jmxremote"
# JAVA_OPTS="$JAVA_OPTS -Djavax.management.builder.initial=org.jboss.system.server.jmx.MBeanServerBuilderImpl"
# JAVA_OPTS="$JAVA_OPTS -Dcom.sun.management.jmxremote.port=9001 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"

# enable jon monitoring
JAVA_OPTS="$JAVA_OPTS -Djboss.platform.mbeanserver"' >> $JBOSS_HOME/bin/run.conf

if [[ -z ${#MEM_MEG} ]] ; then
  echo "detected standalone mode, must repeat system variables"
	CPUS=`grep processor /proc/cpuinfo | wc -l`
	MEM_MEG=$((`cat /proc/meminfo | grep MemTotal: | cut -d ":" -f 2 | cut -d "k" -f1`/1024))
	MEM=$(($MEM_MEG/2048))
fi

## memory example (using huge pages)
## total system memory: 5963m
## total j2ee memory as reported by top:VIRT: 4662m(jboss)+572m(jon) = 5234m
## total j2ee memory by JVM configurations: 3072+512+1024+64+128=4736 (huge)
## jbossas: Xms,Xmx: 3072m; PermSize, MaxPermSize: 512m; NewSize,MaxNewSize: 1024m; ReservedCodeCacheSie: 64m
## jonagnet/rhq: Xms,Xmx: 64m-128m
## system memory should be at least 512m
## jon agent will use 562m
## jboss will use remainder: Xms,Xmx=60% of remainder; PermSize,MaxPermSize=10%; NewSize,MaxNewSize=15%; ReservedCodeCacheSize=2%
## in sun jdk 1.6, upper limit is 256 for PermSize and 512 for MaxPermSize. Default is 256 for MaxPermSize.

echo "CPUS is $CPUS"
if [ ${MEM_MEG} -lt 1536 ] ; then echo "SYSTEM MAY NOT HAVE ENOUGH MEMORY"; fi
echo "MEM_MEG is $MEM_MEG"
echo "MEM is $MEM"

JVM=$(($MEM_MEG-512-562))
if [ ${JVM} -lt 768 ] ; then echo "SYSTEM MAY NOT HAVE ENOUGH MEMORY"; JVM=768 ; fi
echo "JVM is $JVM"
XMX=$(($JVM*60/100))
echo "XMX is $XMX"
MAXPERM=$(($JVM*10/100))
if [ ${MAXPERM} -gt 512 ] ; then MAXPERM=512 ; fi
echo "MAXPERM is $MAXPERM"
PERM=$(($MAXPERM))
if [ ${PERM} -gt 256 ] ; then PERM=256 ; fi
echo "PERM is $PERM"
NEW=$(($JVM*15/100))
echo "NEW is $NEW"
RES=$(($JVM*2/100))
echo "RES is $RES"

sed -ci "s/Xms1303m/Xms${XMX}m/" $JBOSS_HOME/bin/run.conf
sed -ci "s/Xmx1303m/Xmx${XMX}m/" $JBOSS_HOME/bin/run.conf
sed -ci "s/PermSize=128m/PermSize=${MAXPERM}m/" $JBOSS_HOME/bin/run.conf
sed -ci "s/MaxPermSize=512m/MaxPermSize=${MAXPERM}m/" $JBOSS_HOME/bin/run.conf

echo "force garbage collection every half hour instead of every hour"
# http://www.tikalk.com/java/application-freezes-too-many-full-gcs
sed -ci 's/gcInterval=3600000/gcInterval=1800000/g' $JBOSS_HOME/bin/run.conf
echo "if multiple cpus, use parallel garbage collection"
if [[ "${CPUS}" -gt 1 ]] ; then
	sed -ci "s/ParallelGCThreads=2/ParallelGCThreads=${CPUS}/g" $JBOSS_HOME/bin/run.conf
	echo "uncomment concurrent garbage collection line for low pause, high throughput apps"
	NUM1=`grep -n "UseConcMarkSweepGC" $JBOSS_HOME/bin/run.conf | cut -d ":" -f1`
	sed -ci "${NUM1}s/^#\ //" $JBOSS_HOME/bin/run.conf
fi

# replace eden space values
sed -ci "s/NewSize=1024m/NewSize=${NEW}m/g" $JBOSS_HOME/bin/run.conf
sed -ci "s/MaxNewSize=1024m/MaxNewSize=${NEW}m/g" $JBOSS_HOME/bin/run.conf
sed -ci "s/ReservedCodeCacheSize=64m/ReservedCodeCacheSize=${RES}m/g" $JBOSS_HOME/bin/run.conf

# rerun setperms.sh as sed would remove any ACL entries --update: not if you use sed -ci ...
# bash $JBOSS_HOME/bin/setperms.sh
) 2>&1 | tee -a $OUT
