### VARIABLES ###

DOMAIN=example.com
CLIENT=acme
echo "determine standalone or kickstart"
#raw
if [[ ${#server} -gt 1 ]] ; then
  echo "kickstart detected"
	echo "TODO: this variable is not detected in a cobbler kickstart"
else
	echo "standalone detected"
	server=server1."${DOMAIN}"
	jboss_var=EAP
fi
export KICKSTART_HOST=$server
LOCALDC=10.2.1.1
DISTRO_VERSION=5.1.2
BACKUP_SERVER=datadomain."${DOMAIN}":/backup/linux
export PURPOSE=`echo $(hostname) | cut -c 8-10 | tr '[A-Z]' '[a-z]'`
#end raw
# define the flavor of jdk preferred for jboss servers
# jon agents only need the jre, not the jdk and can use openjdk
JDK=java-1.6.0-sun
JCE=0
SESSIONTIMEOUT=30

echo "security variables"
#raw
SSL=0
ADMIN_PASSWORD=example
SQLHOST=sqlserver."${DOMAIN}"
SQLINSTANCE=sqlinstance
SQLUSER=sqluser
SQLPASS=sqlpassword
#end raw

#raw
echo "hardware variables"
export CPUS=`grep processor /proc/cpuinfo | wc -l`
echo "find multiples of 2GB"
CPUS=`grep processor /proc/cpuinfo | wc -l`
MEM_MEG=$((`cat /proc/meminfo | grep MemTotal: | cut -d ":" -f 2 | cut -d "k" -f1`/1024))
MEM=$(($MEM_MEG/2048))
#end raw

echo "rhq variables"
export PRODJON=jon."${DOMAIN}"
export TESTJON=jontest."${DOMAIN}"
export ENV=`echo $(hostname) | cut -c 1 | tr '[A-Z]' '[a-z]'`
if [[ "$ENV" == 'd' ]] ; then ENV='dev'
elif [[ "$ENV" == 't' ]] ; then ENV='test'
elif [[ "$ENV" == 'q' ]] ; then ENV='qa'
elif [[ "$ENV" == 'm' ]] ; then ENV='mo'
elif [[ "$ENV" == 'p' ]] ; then ENV='prod'
else ENV='test'
fi

echo "slim variables"
echo "dependencies are automatically retained"
# TODO: move these to cobbler meta info tags so they are specific to the server
SLIM_AJP=1
SLIM_BSHDEPLOYER=1
# recommend to slim
SLIM_CLUSTER=1
SLIM_DATASOURCE=0
SLIM_EJB2=1
SLIM_EJB3=0
# recommend to slim
SLIM_HOT=1
# recommend to slim
SLIM_HYPER=1
SLIM_IIOP=1
SLIM_INVOKER_HTTP=1
SLIM_INVOKER_IIOP=1
# recommended to keep
SLIM_INVOKER_JMX=0
# recommended to keep
SLIM_INVOKER_LEGACYJRMP=0
SLIM_INVOKER_POOLED=1
# recommended to keep
SLIM_JCA=0
# recommend to slim
SLIM_JUDDI=1
# recommend to slim
SLIM_KEYGENUUID=1
SLIM_MAIL=0
# recommend to slim if JON exists
SLIM_MANAGEMENT=1
SLIM_MESSAGING=1
SLIM_PROFILESERVICE=1
SLIM_PROPERTIESSERVICE=1
SLIM_REMOTING=0
SLIM_SCHEDULER=0
SLIM_SEAM=1
SLIM_SNMP=1
# recommend to keep
SLIM_TRANSACTION=0
# recommend to keep
SLIM_WEB=0
SLIM_WSCLIENT=0
SLIM_WSSERVER=1
SLIM_XNIO=1

echo "other"
if [[ "${SLIM_CLUSTER}" -eq 1 ]] ; then
	export JBOSS_CONF=${CLIENT}-nocluster
else
	export JBOSS_CONF=${CLIENT}-cluster
fi
### DOWNLOAD ###
echo "download jboss zip, create links"
cd /usr/local
##Cheetah logic to switch between jboss installs
#if $getVar('$jboss_var', None) == "EAP"
	wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/jboss-eap-${DISTRO_VERSION}.zip --output-document=/usr/local/jboss-eap-${DISTRO_VERSION}.zip
	unzip jboss-eap-${DISTRO_VERSION}.zip
	ln -s jboss-eap-5.1/ jboss
	rm -vf jboss-eap-${DISTRO_VERSION}.zip
#elif $getVar('$jboss_var', None) == "EWP"
	wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/jboss-ewp-${DISTRO_VERSION}.zip --output-document=/usr/local/jboss-ewp-${DISTRO_VERSION}.zip
	unzip jboss-ewp-${DISTRO_VERSION}.zip
	ln -s jboss-ewp-5.1/ jboss
	cd jboss/; ln -s jboss-as-web/ jboss-as ; cd /usr/local
	rm -vf jboss-ewp-${DISTRO_VERSION}.zip
#else
	logger -p local1.info -t kickstart-jboss "Unable to determine jboss install switch"
	# break
#end if

echo "set global variables"
echo "
# jboss
export JBOSS_HOME=/usr/local/jboss/jboss-as
export JBOSS_CONF=${JBOSS_CONF}" >> /etc/profile
echo 'alias cdj="cd ${JBOSS_HOME}/server/${JBOSS_CONF}"' >> /etc/bashrc

source /etc/profile

if [[ "${SLIM_CLUSTER}" -eq 0 ]] ; then
	echo "copy from production node"
	cp -a $JBOSS_HOME/server/production $JBOSS_HOME/server/$JBOSS_CONF
	echo "protect original node"
	chmod -R ugo-w $JBOSS_HOME/server/production/
else
	echo "copy from default node"
	cp -a $JBOSS_HOME/server/default $JBOSS_HOME/server/$JBOSS_CONF
	echo "protect original node"
	chmod -R ugo-w $JBOSS_HOME/server/default/
fi

### ACCESS ###
# must declare firewall rules before slimming script is run
# create separate rule set, customize, then insert into iptables
echo "firewall changes. initially assume syntax > RHEL 5"
echo "ports from https://access.redhat.com/sites/default/files/slimtrimpruneeap.pdf"

cat << EOF >> /etc/sysconfig/iptables-jboss

# rhq/jon agent for jboss monitoring
-A INPUT -m state --state NEW -m tcp -p tcp --dport 16163 -j ACCEPT

### BEGIN JBOSS RULES ###
# ajp
-A INPUT -m state --state NEW -m tcp -p tcp --dport 8009 -j ACCEPT

# web
-A INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT
# ssl (disabled)
# -A INPUT -m state --state NEW -m tcp -p tcp --dport 8443 -j ACCEPT
# ejb3 (fagordnc)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 3873 -j ACCEPT
# rmi
-A INPUT -m state --state NEW -m tcp -p tcp --dport 1098 -j ACCEPT
# jnp/jndi
-A INPUT -m state --state NEW -m tcp -p tcp --dport 1099 -j ACCEPT
# web service
-A INPUT -m state --state NEW -m tcp -p tcp --dport 8083 -j ACCEPT

# cluster
-A INPUT -m state --state NEW -m tcp -p tcp -m multiport --dports 54200,54201 -j ACCEPT
# cluster (ha rmi/jrmp)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4447 -j ACCEPT
# cluster (pooled ha)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4448 -j ACCEPT
# ha jndi
-A INPUT -m state --state NEW -m tcp -p tcp --dport 1100 -j ACCEPT
# ha jndi rmi
-A INPUT -m state --state NEW -m tcp -p tcp --dport 1101 -j ACCEPT

# messaging/jms
-A INPUT -m state --state NEW -m tcp -p tcp -m multiport --dports 7900,57900,53200,43830 -j ACCEPT
# jca?
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4457 -j ACCEPT
# legacy invokers (rmi/jrmp)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4444 -j ACCEPT
# legacy invokers (pooled)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4445 -j ACCEPT
# transactions (recovery mgr)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4712 -j ACCEPT
# transactions (tx status mgr)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4713 -j ACCEPT
# remoting
-A INPUT -m state --state NEW -m tcp -p tcp --dport 4446 -j ACCEPT
# iiop (jboss-ii)
-A INPUT -m state --state NEW -m tcp -p tcp --dport 3528 -j ACCEPT
# iiop (jboss-ii) SSL
-A INPUT -m state --state NEW -m tcp -p tcp --dport 3529 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 3529 -j ACCEPT
# jmx remote (disabled)
# -A INPUT -m state --state NEW -m tcp -p tcp --dport 9001 -j ACCEPT
### END JBOSS RULES ###

EOF

echo "detect RHEL 5 and change INPUT prefix accordingly"
if ( grep -q '5\.' /etc/redhat-release ) ; then
	sed -ci 's/INPUT/RH-Firewall-1-INPUT/g' /etc/sysconfig/iptables-jboss
	echo "replaced with RHEL5 syntax in iptables"
fi

if [[ "${SLIM_AJP}" -eq 0 ]] ; then
	echo "if using apache load balancing (mod_jk), make sure ajp is enabled in jboss and add jvmRoute. see Administration and Configuration Guide p191-196"
	echo "load balancing documentation http://lbconfig.appspot.com/"
	echo "see apache reverse proxy documentation at https://docs.google.com/document/d/1Q5iMm16sKkVl2LKu8ae1srCh-EEK8sq1j_WE1QO5hgc/edit?hl=en&authkey=CIqoneIH"
	if ! grep -qi jvmRoute $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml ; then
		#raw
		echo "set ajp route and nodename which must match apache worker.properties"
		echo "grab last 4 digits of hostname (assuming they are numbers in TMNAS naming convention"
		NUMBER=`echo $(hostname -s) | sed 's/[a-z]//g'`
		sed -ci "s/defaultHost=\"localhost\"/defaultHost=\"localhost\"\ jvmRoute=\"${PURPOSE}_${ENV}_node${NUMBER}\"/" $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml
		#end raw
	fi
fi

# LOAD BALANCING
#raw
if `echo $(hostname -s) | cut -c 1-2 | grep -qi 'P0\|M0' ` ; then
	echo "Model office and production systems should be redundant and therefore load balanced"
	echo "lock down port access to certain subnets"
	# 10.1.1.0/24 for VDI
	# 10.2.2.0/24 for operations
	# 10.3.3.0/24 for vendor tunnel?
	# X.250,X.251,X.252 for F5s where X is the first 3 octets of the local ip
	PREFIX=`echo $IP_ADDRESS | cut -d "." -f1-3`
	F5="${PREFIX}.250,${PREFIX}.251,${PREFIX}.252"
	for i in 8009 8080 8443 3873 1098 1099 8083 54200,54201 4448 7900,57900,53200,43830 4457 4444 4445 4447 4712 4713 4446 1100 1101 3528 3529 9001 ; do
		sed -ci "s/-m\ state\ --state\ NEW\ -m\ tcp\ -p\ tcp\ --dport\ $i\ -j\ ACCEPT/-s\ 10.1.1.0\/24\,10.2.2.0\/24\,10.3.3.0\/24\,${F5} -m\ state\ --state\ NEW\ -m\ tcp\ -p\ tcp\ --dport\ $i\ -j\ ACCEPT/" /etc/sysconfig/iptables-jboss
		sed -ci "s/-m\ state\ --state\ NEW\ -m\ tcp\ -p\ tcp\ -m\ multiport\ --dports\ $i\ -j\ ACCEPT/-s\ 10.1.1.0\/24\,10.2.2.0\/24\,10.3.3.0\/24\,${F5} -m\ state\ --state\ NEW\ -m\ tcp\ -p\ tcp\ --dport\ $i\ -j\ ACCEPT/" /etc/sysconfig/iptables-jboss
	done
fi
#end raw

sed -ci -e '/-A\ INPUT\ -j\ REJECT\ --reject-with\ icmp-host-prohibited/r /etc/sysconfig/iptables-jboss' -e 'x;$G' /etc/sysconfig/iptables
rm -f /etc/sysconfig/iptables-jboss

### SLIMMING ###

cd $JBOSS_HOME/server
wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/slim5.sh --output-document=$JBOSS_HOME/server/slim5.sh
chmod ug+x ./slim5.sh
./slim5.sh ${SLIM_AJP} ${SLIM_BSHDEPLOYER} ${SLIM_CLUSTER} ${SLIM_DATASOURCE} ${SLIM_EJB2} ${SLIM_EJB3} ${SLIM_HOT} ${SLIM_HYPER} ${SLIM_IIOP} ${SLIM_INVOKER_HTTP} ${SLIM_INVOKER_IIOP} ${SLIM_INVOKER_JMX} ${SLIM_INVOKER_LEGACYJRMP} ${SLIM_INVOKER_POOLED} ${SLIM_JCA} ${SLIM_JUDDI} ${SLIM_KEYGENUUID} ${SLIM_MAIL} ${SLIM_MANAGEMENT} ${SLIM_MESSAGING} ${SLIM_PROFILESERVICE} ${SLIM_PROPERTIESSERVICE} ${SLIM_REMOTING} ${SLIM_SCHEDULER} ${SLIM_SEAM} ${SLIM_SNMP} ${SLIM_TRANSACTION} ${SLIM_WEB} ${SLIM_WSCLIENT} ${SLIM_WSSERVER} ${SLIM_XNIO}

### OS TUNING ###

echo "increase open file limit"
cat << EOF >> /etc/security/limits.conf

# double open file limit for user jboss
jboss	hard	nofile	2048
jboss	soft	nofile	2048
EOF

echo "huge pages"
echo "https://access.redhat.com/kb/docs/DOC-2593" 
echo "for calculations, see page 18 of http://www.jboss.com/pdf/JB_JEAP5_PerformanceTuning_wp_web.pdf"
echo "or page 30-33 of http://www.redhat.com/promo/summit/2010/presentations/jbossworld/optimize-secure-manage/thurs/amiller-1130-accelerate/Accelerate-Your-JBoss.pdf"
echo "make sure OS is 64 bit, JVM is 64 bit, and memory is 4GB+"
cp $JBOSS_HOME/bin/run.conf $JBOSS_HOME/bin/run.bak
if [ `uname -p` == "x86_64" ] && (rpm -qi "${JDK}".x86_64 | grep -qi Version) && [ "${MEM}" -ge 2 ] ; then
	echo 'JAVA_OPTS="$JAVA_OPTS -XX:+UseLargePages"' >> $JBOSS_HOME/bin/run.conf
	echo "if RHEL 5.x, configure huge pages; should be automatic in RHEL 6+"
	if ( grep -q '6\.' /etc/redhat-release ) ; then
		echo "https://access.redhat.com/knowledge/solutions/46111"
		logger -p local1.info -t kickstart-jboss "Did not configure huges pages. Your JVM is 64 bit but RHEL 6.x should transparently have huge pages."
		echo "ensure transparent huge pages are enabled (taken from RH442 webinar)"
		THP_ENABLE="/sys/kernel/mm/redhat_transparent_hugepage/enabled"
		THP_SAVE="/var/run/tuned/ktune-thp.save"
		if [ -e $THP_ENABLE ]; then
			cut -f2 -d'[' $THP_ENABLE  | cut -f1 -d']' > $THP_SAVE
			(echo always > $THP_ENABLE) &> /dev/null
		fi
	elif ( grep -q '5\.\|4\.' /etc/redhat-release ) ; then
		echo "TODO: dynamically calculate memory values based on ${MEM}"
		cat << EOF >> /etc/security/limits.conf

# increase memory lock for user jboss
jboss	hard	memlock `echo $((1400000*$MEM))`
jboss	soft	memlock `echo $((1400000*$MEM))`
EOF
		echo "TODO: should be half the number of MB of memory reserved for huge pages"
		echo "vm.nr_hugepages = 2048" >> /etc/sysctl.conf
		# cat /proc/sys/kernel/shmmax
	else
		logger -p local1.info -t kickstart-jboss "Did not configure huge pages since the OS is unknown"
	fi
else
	logger -p local1.info -t kickstart-jboss "Did not configure huge pages since you do not have a 64 bit JVM"
fi

### THREAD TUNING ###
echo "see page 7 of http://www.jboss.com/pdf/JB_JEAP5_PerformanceTuning_wp_web.pdf"
echo "also page 8 of http://www.redhat.com/promo/summit/2010/presentations/jbossworld/optimize-secure-manage/thurs/amiller-1130-accelerate/Accelerate-Your-JBoss.pdf"
echo "see http://www.redhat.com/summit/2011/presentations/jbossworld/taste_of_training/friday/Raposa_JBoss_EAP5_Troubleshooting_Part_1.pdf"
echo "finally http://lbconfig.appspot.com/ for apache settings, ajp connectionTimeout setting, and maxThreads"

echo "first declare settings on http connector and copy to ajp connector"
sed -ci 's/connectionTimeout=\"20000\"\ redirectPort=\"8443\"/connectionTimeout=\"20000\"\ redirectPort=\"8443\"\ maxThreads=\"200\"\ maxHttpHeaderSize=\"8192\"/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml
sed -ci 's/redirectPort=\"8443\"\ \/>/connectionTimeout=\"20000\"\ redirectPort=\"8443\"\ maxThreads=\"200\"\ \/>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml

echo "http/ajp thread pools can be doubled for every 1CPU/2GB RAM/JVM process"
if [[ "${CPUS}" -gt 1 && "${MEM}" -ge 2 ]] ; then
	echo "httpd and ajp thread pools"
	sed -ci 's/connectionTimeout=\"20000\"\ redirectPort=\"8443\"\ maxThreads=\"200\"\ /connectionTimeout=\"40000\"\ redirectPort=\"8443\"\ maxThreads=\"400\"\ /g' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml
fi

echo "only tune as needed on the below threads by monitoring the values in jmx-console"
echo "system thread pool (rarely needs changing)"
# sed -ci 's/MaximumPoolSize\">10/MaximumPoolSize\">20/' $JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-service.xml

echo "jca thread pool"
# sed -ci 's/maximumPoolSize\">100/maximumPoolSize\">200/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jca-jboss-beans.xml
# sed -ci 's/maximumQueueSize\">1024/maximumQueueSize\">2048/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jca-jboss-beans.xml
# sed -ci 's/keepAliveTime\">60000/keepAliveTime\">120000/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jca-jboss-beans.xml

echo "jboss messaging thread pool for remote clients over TCP (unless already slimmed)"
# sed -ci 's/?/?/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/remoting-bisocket-service.xml

echo "jboss messaging thread pool for JVM clients (unless already slimmed)"
echo "utilizes jca thread pool"

echo "EJB (remote clients)"
# sed -ci 's/?/?/g' $JBOSS_HOME/server/$JBOSS_CONF/deployers/ejb3.deployer/META-INF/jboss-service.xml ??

echo "ejb3 object pools"
# sed -ci 's/StrictMaxPool\"\,\ maxSize=15\,\ timeout=10000/StrictMaxPool\"\,\ maxSize=30\,\ timeout=20000/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb3-interceptors-aop.xml

### CACHE TUNING ###
echo "tune as needed by monitoring jmx-console"
echo "see page 17 of http://www.redhat.com/promo/summit/2010/presentations/jbossworld/optimize-secure-manage/thurs/amiller-1130-accelerate/Accelerate-Your-JBoss.pdf"
echo "see http://www.redhat.com/summit/2011/presentations/jbossworld/taste_of_training/friday/Raposa_JBoss_EAP5_Troubleshooting_Part_1.pdf"
# TODO: sed -ci 's/?/?/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/?/*persistence.xml
# TODO: sed -ci 's/?/?/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/cluster/jboss-cache-manager.sar/META-INF/jbosscache-manager-jboss-beans.xml

### BASIC JVM TUNING ###
echo "see tunejvm.sh for references"
cd $JBOSS_HOME/bin/
cp run.conf run.conf.bak

echo "download and execute JVM tuning script which can be ran now and anytime system resources are changed"
cd $JBOSS_HOME/bin/
wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/tunejvm.sh --output-document=$JBOSS_HOME/bin/tunejvm.sh
chmod ug+x ./tunejvm.sh
./tunejvm.sh

### LOG TUNING ###
echo "see http://www.redhat.com/summit/2011/presentations/jbossworld/taste_of_training/friday/Raposa_JBoss_EAP5_Troubleshooting_Part_1.pdf"

echo "decrease bootstrap log level to WARN"
mkdir -p /tmp/run.jar-tmp/; cd /tmp/run.jar-tmp/
cp -a $JBOSS_HOME/bin/run.jar /tmp/run.jar-tmp/
unzip /tmp/run.jar-tmp/run.jar
rm -f /tmp/run.jar-tmp/run.jar
echo "log4j.appender.FILE.Threshold=WARN" >> /tmp/run.jar-tmp/log4j.properties
sed -ci 's/INFO/WARN/g' /tmp/run.jar-tmp/log4j.properties
# add M switch to jar command to skip overwriting the META-INF/MANIFEST, otherwise this breaks rhq-agent jboss info import
find . | xargs jar -cfM run.jar
cd /tmp/
rm -f $JBOSS_HOME/bin/run.jar; cp -af /tmp/run.jar-tmp/run.jar $JBOSS_HOME/bin/; rm -rf /tmp/run.jar-tmp/

echo "move log to /var"
mkdir -p /var/log/jboss/$JBOSS_CONF/
mkdir -p /var/log/jboss/app/
cd $JBOSS_HOME/server/$JBOSS_CONF/
rm -vrf log/ 2> /dev/null
ln -s /var/log/jboss/$JBOSS_CONF log
ln -s /var/log/jboss/app logs

cd $JBOSS_HOME/server/$JBOSS_CONF/conf/
mv jboss-log4j.xml jboss-log4j.xml.bak
wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/prebuilt5/jboss-log4j.xml --output-document=$JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-log4j.xml
sed -ci 's/DefaultJBossServerLogThreshold">INFO/DefaultJBossServerLogThreshold">WARN/' $JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-service.xml

# #raw
# if [[ "${SLIM_CLUSTER}" -eq 1 ]] ; then
# 	echo "remove cluster logging"
# 	NUM1=`grep -n Clustering $JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-log4j.xml | cut -d ":" -f1`
# 	NUM2=$((${NUM1}+23))
# 	sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-log4j.xml
# 
#	NUM1=`grep -n "Limit the org.jgroups" $JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-log4j.xml | cut -d ":" -f1`
#	NUM2=$((${NUM1}+3))
# 	sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-log4j.xml
# fi
# #end raw

### OTHER TUNING ###
echo "clear work dir on restart"
sed -ci 's/name\="deleteWorkDirOnContextDestroy">false/name\="deleteWorkDirOnContextDestroy">true/' $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossweb.deployer/META-INF/war-deployers-jboss-beans.xml

echo "disable DEBUG mbeans to reduce memory usage (may already be commented out)"
sed -ci '/org.jboss.deployers.plugins.deployers.DeployersImplMBean.class/d' $JBOSS_HOME/server/$JBOSS_CONF/conf/bootstrap/deployers.xml

echo "TODO: allow symlinking"
# allowLinking="true" inside $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossweb.deployer/context.xml or server.xml ?

echo "increase session timeout"
sed -ci "s/<session-timeout>30<\/session-timeout>/<session-timeout>${SESSIONTIMEOUT}<\/session-timeout>/g" $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossweb.deployer/web.xml

echo "mechanically enforce standards wherever possible: isolated class loading"
sed -ci 's/isolated">false/isolated">true/' $JBOSS_HOME/server/$JBOSS_CONF/deployers/ear-deployer-jboss-beans.xml
# sed -ci 's/java2ClassLoadingCompliance">false/java2ClassLoadingCompliance">true/' $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossweb.deployer/web.xml

echo "TODO: how to move app to ROOT context"
# rm -vrf $JBOSS_HOME/server/$JBOSS_CONF/deploy/ROOT.war/
# sed -ci 's/<context-root>MYAPP.war<\/context-root>/<context-root>\/<\/context-root>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/MYAPP.war/WEB-INF/jboss-web.xml

### DATASOURCE ###
if [[ "${SLIM_DATASOURCE}" -eq 0 || "${SLIM_MESSAGING}" -eq 0 || "${SLIM_JUDDI}" -eq 0 || "${SLIM_KEYGENUUID}" -eq 0 ]] ; then
	echo "install jdbc driver"
	JDBCDIR=/usr/local/share/microsoft/jdbc
	mkdir -p $JDBCDIR
	wget -nv "http://$server/Microsoft/JDBC/sqljdbc.tgz" -O /tmp/sqljdbc.tgz
	(umask 222
	cd $JDBCDIR
	tar xf /tmp/sqljdbc.tgz
	)
	rm -f /tmp/sqljdbc.tgz
	
	cd $JBOSS_HOME/server/$JBOSS_CONF/deploy/
	wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/prebuilt5/mssql-ds.xml --output-document=$JBOSS_HOME/server/$JBOSS_CONF/deploy/mssql-ds.xml
	echo "connection pooling tuning"
	echo "should be done on a per database connection basis"
	echo "See Jboss EAP 5 Perf Tuning: https://docs.google.com/Doc?docid=0ASZ3fCT4e0KLZGZkcG12c2dfMjIxZmhncmpoZzg&hl=en"
		
	echo "replace values"
	sed -ci "s/sqlserver.example.com/${SQLHOST}/" $JBOSS_HOME/server/$JBOSS_CONF/deploy/mssql-ds.xml
	sed -ci "s/database1/${SQLINSTANCE}/" $JBOSS_HOME/server/$JBOSS_CONF/deploy/mssql-ds.xml
	sed -ci "s/<user-name>x/<user-name>${SQLUSER}/" $JBOSS_HOME/server/$JBOSS_CONF/deploy/mssql-ds.xml
	sed -ci "s/<password>y/<password>${SQLPASS}/" $JBOSS_HOME/server/$JBOSS_CONF/deploy/mssql-ds.xml
	if [[ "${SLIM_HYPER}" -eq 0 ]] ; then
		sed -ci 's/DefaultDS/OtherDS/g' $JBOSS_HOME/server/$JBOSS_CONF/deploy/mssql-ds.xml
	fi
	
	echo "link jdbc driver (already downloaded as part of base jboss install)"
	ln -s /usr/local/share/microsoft/jdbc/sqljdbc4.jar $JBOSS_HOME/server/$JBOSS_CONF/lib/
	
	echo "TODO: encrypt password, see Admin and Configuration Guide p95 or JB336 book p149"
	# move to SECURITY section?
	# cd $JBOSS_HOME/
	# java -cp lib/jboss-logging-spi.jar:common/lib/jbosssx.jar org.jboss.resource.security.SecureIdentityLoginModule mypassword
fi

### AUTO START ###
echo "download jboss startup script (since it was accidentally left out of 5.1.x)"
rm -vf $JBOSS_HOME/bin/jboss_init_redhat.sh
wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/prebuilt5/jboss_init_redhat.sh --output-document=$JBOSS_HOME/bin/jboss_init_redhat.sh
chmod 775 $JBOSS_HOME/bin/jboss_init_redhat.sh
cd /etc/init.d/
ln -s $JBOSS_HOME/bin/jboss_init_redhat.sh jbossas

source /etc/profile
sed -ci "s/default/${JBOSS_CONF}/" $JBOSS_HOME/bin/jboss_init_redhat.sh

# TODO: convert init script variables to separate /etc/sysconfig file
# TODO: do not rely on jboss user having a valid shell (/sbin/nologin, /bin/false) and provides cluster variables

chkconfig jbossas on

### CLUSTERING ###
echo "TODO: clustering"
echo "load balancing documentation: http://lbconfig.appspot.com/"

if [[ "${SLIM_CLUSTER}" -eq 1 ]] ; then
	echo "create a clustered JMS queue (using tcp) ? see Administration and Configuration Guide p207 or p86"
else
	echo "no clustering configuration will be performed"
fi

### SECURITY ###
if [[ "${JCE}" -eq 1 ]] ; then
	mkdir -p /usr/local/share/sun/jce/
echo "#!/bin/bash
JDK=${JDK}
KICKSTART_HOST=${KICKSTART_HOST}
" >> /usr/local/share/sun/jce/freshenjavajce.sh

	cat << EOF >> /usr/local/share/sun/jce/freshenjavajce.sh
echo "see http://www.ngs.ac.uk/tools/jcepolicyfiles"
echo "download from http://www.oracle.com/technetwork/java/javase/downloads/index.html to http://${KICKSTART_HOST}/jboss_files/jdk/jce/"
echo "turn off any java instances"
if [ -h /etc/init.d/jbossas ] ; then service jbossas stop; fi
if [ -h /etc/init.d/jonagent] ; then service jonagent stop; fi

if ! grep -qi "exclude=${JDK}" /etc/yum.conf ; then
	echo "exclude=${JDK}*" >> /etc/yum.conf
fi
echo "install java jre if necessary"
if ! ( rpm -qa | grep -qi "${JDK}" ); then
	if [ `uname -p` == "x86_64" ] ; then
		yum install -y "${JDK}".x86_64
	else
		yum install -y "${JDK}"
	fi
fi
yum --disableexcludes=${JDK}* update -y ${JDK} ${JDK}-devel

echo "install jdk crypto files"
echo "jce files are not specific to 32-bit or 64-bit..."
mkdir -p /usr/local/share/sun/jce/
for jar in local_policy.jar mkdir -p /usr/local/share/sun/jce/ ; do
	wget -nv http://${KICKSTART_HOST}/jboss_files/jdk/jce/$jar --output-document=/usr/local/share/sun/jce/$jar
	cd /usr/local/share/sun/jce/
	JCE1=`find /usr/lib/ -type f -name $jar`
	dir1=`dirname ${JCE1}`
	cd $dir1
	mv $jar "${jar}".orig
	ln -s /usr/local/share/sun/jce/$jar $jar
done

service jbossas start
service jonagent start
EOF

	chmod u+x /usr/local/share/sun/jce/freshenjavajce.sh
	echo "check for required package"
	if ! ( rpm -qa | grep -q ^at- ); then
		yum install -y at.`uname -p`
	fi
	service atd start
	echo "/bin/bash /usr/local/share/sun/jce/freshenjavajce.sh" | at now + 20 minutes
else
	echo "did not install java jce crypto files"
fi

echo "https://access.redhat.com/sites/default/files/securing_eap.pdf"
echo "enforce console security for all modules"
echo "TODO: create read only role/login for developers"

echo "jmx console (already done)"
echo "<security-domain> node should already be uncommented"
# sed -ci 's/<!--\ <security-domain>java:\/jaas\/jmx-console<\/security-domain>/<security-domain>java:\/jaas\/jmx-console<\/security-domain>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jmx-console.war/WEB-INF/jboss-web.xml
echo "<security-constraint> node should already be uncommented"
# sed -ci 's/<!--\ <security-contraint>/<security-constraint>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jmx-console.war/WEB-INF/web.xml
 
echo "web console (already done)"
echo "<security-domain> node should already be uncommented"
# <security-domain>java:\/jaas\/web-console<\/security-domain>/<security-domain>java:\/jaas\/web-console<\/security-domain>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/management/console-mgr.sar/web-console.war/WEB-INF/jboss-web.xml
echo "<security-constraint> node should already be uncommented"
# sed -ci 's/<!--\ <security-contraint>/<security-constraint>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/management/console-mgr.sar/web-console.war/WEB-INF/web.xml
 
echo "http invoker (already done)"
echo "<security-domain> node should already be uncommented"
# sed -ci 's/<!--\ <security-domain>java:\/jaas\/jmx-console<\/security-domain>/<security-domain>java:\/jaas\/jmx-console<\/security-domain>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/httpha-invoker.sar/invoker.war/WEB-INF/jboss-web.xml
echo "<security-constraint> node should already be uncommented"
# sed -ci 's/\#<security-contraint/<security-constraint.*/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/httpha-invoker.sar/invoker.war/WEB-INF/web.xml
 
echo "jmx invoker (already done)"
echo "securityDomain should already be uncommented"
# sed -ci 's/<!--\ <interceptor code=\"org.jboss.jmx.connector.invoker.AuthenticationInterceptor\"/<interceptor code=\"org.jboss.jmx.connector.invoker.AuthenticationInterceptor\"/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jmx-invoker-service.xml
# sed -ci 's/securityDomain=\"java:\/jaas\/jmx-console\"\/>\ -->/securityDomain=\"java:\/jaas\/jmx-console\"\/>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jmx-invoker-service.xml
 
echo "profileservice (already done)"
echo "securityDomain should already be set to jmx-console"
# sed -ci 's/securityDomain.*/securityDomain\">jmx-console<\/property>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/profileservice-jboss-beans.xml
 
echo "jbossws (already done)"
echo "<security-domain> node should already be uncommented"
# sed -ci 's/<!--\ <security-domain>java:\/jaas\/jmx-console<\/security-domain>/<security-domain>java:\/jaas\/jmx-console<\/security-domain>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossws.sar/jbossws-management.war/WEB-INF/jboss-web.xml
echo "<security-constraint> node should already be uncommented"
# sed -ci 's/<!--\ <security-contraint>/<security-constraint>/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossws.sar/jbossws-management.war/WEB-INF/web.xml

echo "change default passwords and tighten password file permissions"
for i in `find -L $JBOSS_HOME/server/ -type f -name "*users.properties"` ; do sed -ci "s/\#\ admin=admin/admin=${ADMIN_PASSWORD}/g" $i; sed -ci "s/admin=admin/admin=${ADMIN_PASSWORD}/g" $i ; chmod -c 440 $i; done
#raw
sed -ci "s/CHANGE.*/${ADMIN_PASSWORD}<\/property\>\ /" $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/messaging-jboss-beans.xml; chmod -c 400 $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/messaging-jboss-beans.xml; sed -ci 's/.$//' $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/messaging-jboss-beans.xml
#end raw
echo "TODO: hook jmx up to ldap? see pages 10 of Getting Started Guide.pdf"

echo "TODO: enable SSL over 8443"
if [[ "${SSL}" -eq 1 ]] ; then
	echo "TODO: uncomment SSL/TLS Connector"
	# sed -ci 's/?/?/g' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml
	# generate ssl cert using openssl or "keytool -genkey -alias tomcat -keyalg RSA -keystore training.keystore -validity 365; cp training.keystore $JBOSS_HOME/server/$JBOSS_CONF/"
	# add/enable 8443 firewall rule, if necessary
	# test redirectPort=8443 functionality
fi

echo "create disabled jboss user with no password"
groupadd -g 101 jboss; useradd -u 101 -g 101 jboss
echo "DenyUsers jboss" >> /etc/ssh/sshd_config

echo 'For patching use JON: http://docs.redhat.com/docs/en-US/JBoss_Operations_Network/2.4/html-single/Basic_Admin_Guide/index.html#Applying_JBoss_Patches'

### PERMISSIONS ###
chown -HLR jboss:jboss /usr/local/jboss/
echo "download and execute group permission script which can be ran now and anytime permissions need to be changed"
cd $JBOSS_HOME/bin/
wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/setperms.sh --output-document=$JBOSS_HOME/bin/setperms.sh
chmod ug+x ./setperms.sh

echo "must schedule this as LDAP is not integrated at build time and LDAP groups would be unrecognized in setfacl commands"
# ./setperms.sh
echo "check for required package"
if ! ( rpm -qa | grep -q ^at- ); then
	yum install -y at.`uname -p`
fi
service atd start
echo "/bin/bash $JBOSS_HOME/bin/setperms.sh" | at now + 10 minutes

### BACKUPS ###
echo "configure backups using cronjob to nfs share"
mkdir -p /Backups/
echo "create backup job"
echo '#!/bin/bash

# fail safe if JBOSS_HOME does not evaluate, exit. Otherwise commands may be applied to root directory
if [ ! -d "${JBOSS_HOME}" ]; then
	echo "Exiting. JBOSS_HOME does not exist as a valid directory : $JBOSS_HOME"
	echo "Ensure you are executing the script as bash ./script.sh"
	exit 1
fi
for i in ${JBOSS_HOME}/server/${JBOSS_CONF}; do
	dir1=`dirname $i`
	base=`basename $i`
	cd $dir1
	mkdir -p /Backups/`hostname`$dir1
	tar -cjf /Backups/`hostname`$dir1/$base.tar.bz2 $base --exclude $JBOSS_CONF/data --exclude $JBOSS_CONF/log --exclude $JBOSS_CONF/logs --exclude $JBOSS_CONF/tmp --exclude $JBOSS_CONF/work
done' > /etc/cron.daily/backup
chmod u+x /etc/cron.daily/backup

echo "check for required nfs packages"
if ! ( rpm -qa | grep -q nfs-utils ); then
	yum install -y nfs-utils.`uname -p`
fi
if ( grep -q '6\.' /etc/redhat-release ) && ! ( rpm -qa | grep -q cifs-utils ); then
	yum install -y rpcbind.`uname -p`
	# chkconfig rpcbind on
elif ( grep -q '5\.' /etc/redhat-release ); th
	yum install -y portmap.`uname -p`
	chkconfig portmap on
fi

echo "configure mount point"
echo "${BACKUP_SERVER} /Backups nfs rsize=32768,wsize=32768,hard,timeo=14,intr,tcp 0 0" >> /etc/fstab
echo "you may have to have the storage team allow the nfs mount on ${BACKUP_SERVER}"
echo "do not mount yet as we will be rebooting shortly"
### MONITORING ###
cd /usr/local
wget -nv http://${KICKSTART_HOST}/jboss_files/jon/rhq-agent-install.sh --output-document=/usr/local/rhq-agent-install.sh
sh ./rhq-agent-install.sh
rm /usr/local/rhq-agent-install.sh
