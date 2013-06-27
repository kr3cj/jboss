#!/bin/bash
# installs rhq-agent silently (aka JBoss Operations Network, J.O.N.)
export AGENT_HOME=/usr/local/rhq-agent
mkdir -p ${AGENT_HOME}
OUT=${AGENT_HOME}/rhq-agent-install_$(date +%m%d%Y-%H%M).log
(

export ENV=`echo $(hostname) | cut -c 1 | tr '[A-Z]' '[a-z]'`
if [[ "$ENV" == 'd' ]] ; then ENV='dev'
elif [[ "$ENV" == 'r' ]] ; then ENV='train'
elif [[ "$ENV" == 't' ]] ; then ENV='test'
elif [[ "$ENV" == 'q' ]] ; then ENV='qa'
elif [[ "$ENV" == 'm' ]] ; then ENV='mo'
elif [[ "$ENV" == 'p' ]] ; then ENV='prod'
else ENV='test'
fi
KICKSTART_HOST=server1.example.com
PRODJON=jon.example.com
TESTJON=jontest.example.com
CLIENT=acme
PURPOSE=`echo $(hostname) | cut -c 8-10 | tr '[A-Z]' '[a-z]'`
JDK=java-1.6.0-sun

echo "### PREREQUISITES ###"
echo "determine which jon server to use"
if `echo ${ENV} | grep -qi "prod\|mo"` ; then
  JON=${PRODJON}
else
	JON=${TESTJON}
fi

echo "add firewall rule if necessary"
if ! grep -q 16163 /etc/sysconfig/iptables ; then
	sed -ci '/ESTABLISHED\,RELATED/a\
\# jon agent\
-A INPUT -m state --state NEW -m tcp -p tcp --dport 16163 -j ACCEPT' /etc/sysconfig/iptables
	echo "detect RHEL 5 and change INPUT prefix accordingly"
	if ( grep -q '5\.' /etc/redhat-release ) ; then
		sed -ci 's/INPUT/RH-Firewall-1-INPUT/g' /etc/sysconfig/iptables
		echo "replaced with RHEL5 syntax in iptables"
	fi
	service iptables restart
fi

echo "install java jre if necessary"
if ! ( rpm -qa | grep -qi "${JDK}" ); then
	if [ `uname -p` == "x86_64" ] ; then
		yum install -y "${JDK}".x86_64
	else
		yum install -y "${JDK}"
	fi
fi

wget -nv http://"${JON}":7080/agentupdate/download --output-document=rhq-enterprise-agent-GA.jar
cd /usr/local
java -jar rhq-enterprise-agent-GA.jar --install
rm -vf rhq-enterprise-agent-GA.jar rhq*.log

echo "rhq-agent-env.sh config"
# sed -ci '/^RHQ_AGENT_HOME.*/d' ${AGENT_HOME}/bin/rhq-agent-env.sh
# sed -ci '/^RHQ_AGENT_JAVA_HOME.*/d' ${AGENT_HOME}/bin/rhq-agent-env.sh
echo "
RHQ_AGENT_HOME=\"${AGENT_HOME}\"" >> $AGENT_HOME/bin/rhq-agent-env.sh
echo "
RHQ_AGENT_JAVA_HOME=\"/usr/lib/jvm/jre\"" >> $AGENT_HOME/bin/rhq-agent-env.sh
fi

echo "add cache clearing to service control script"
sed -ci 's/echo\ "RHQ\ Agent\ has\ stopped\."/find\ $RHQ_AGENT_HOME\/..\/data\/.\ |\ xargs\ rm\ -rf\ 2>\ \/dev\/null\n\techo\ "RHQ\ Agent\ has\ stopped\."/' $AGENT_HOME/bin/rhq-agent-wrapper.sh

echo "auto start"
ln -s $AGENT_HOME/bin/rhq-agent-wrapper.sh /etc/init.d/jonagent
chmod 755 /etc/init.d/jonagent
chkconfig jonagent on

echo 'modify client agent-configuration.xml first (http://docs.redhat.com/docs/en-US/JBoss_Operations_Network/2.4/html-single/Installation_Guide/index.html#using-an-answer-file)'
sed -ci "/<\/map>/i\
<entry\ key=\"rhq.agent.configuration-setup-flag\"\ value=\"true\"\ \/>\
<entry\ key=\"rhq.agent.name\"\ value=\"$(hostname -s)_${PURPOSE}_${ENV}_rhel\"\ \/>\
<entry\ key=\"rhq.communications.connector.bind-address\"\ value=\"$(hostname)\"\ \/>\
<entry\ key=\"rhq.agent.server.bind-address\"\ value=\"${JON}\"\ \/>" ${AGENT_HOME}/conf/agent-configuration.xml
# sed -ci 's/rhq.agent.disable-native-system"\ value="false"/rhq.agent.disable-native-system"\ value="true"/g' ${AGENT_HOME}/conf/agent-configuration.xml
cp ${AGENT_HOME}/conf/agent-configuration.xml ${AGENT_HOME}/conf/new-agent-configuration.xml

sh ${AGENT_HOME}/bin/rhq-agent.sh --cleanconfig --config ${AGENT_HOME}/conf/new-agent-configuration.xml --nostart --daemon

echo "detect and configure any apache customizations"
echo "DISABLED until SNMP module is compatible with selinux"
# if ( rpm -qa | grep -qi ^httpd-2 ); then
#	echo "apache detected, download and configure snmp module"
#	echo 'see: http://docs.redhat.com/docs/en-US/JBoss_Operations_Network/2.4/html-single/Basic_Admin_Guide/index.html#Apache_SNMP_Configuration'
#	mkdir -p /etc/httpd/modules/addon/
#	mkdir -p /var/www/snmp/
#	cd /etc/httpd/modules/addon/

#	if [ `uname -p` == "x86_64" ] ; then
#		for i in libsnmpcommon.so libsnmpmonagt.so libsnmpsubagt.so; do wget -nv http://"${KICKSTART_HOST}"/jboss_files/jon/apache_modules/x86_64/$i --output-document=/etc/httpd/modules/addon/$i; done
#	else
#		for i in libsnmpcommon.so libsnmpmonagt.so libsnmpsubagt.so; do wget -nv http://"${KICKSTART_HOST}"/jboss_files/jon/apache_modules/x86/$i --output-document=/etc/httpd/modules/addon/$i; done
#	fi
	
#	wget -nv http://"${KICKSTART_HOST}"/jboss_files/jon/apache_modules/snmpd.conf --output-document=/etc/httpd/conf/snmpd.conf
#	cd /etc/httpd/modules/
#	ln -s addon/* .
#	chcon -c --reference /etc/httpd/conf/workers.properties /etc/httpd/conf/snmp.conf
#	chcon -c --reference /var/www/html/ /var/www/snmp/

#	echo "
# # snmp module for jon agent
# LoadModule snmpcommon_module modules/libsnmpcommon.so
# LoadModule snmpagt_module modules/libsnmpmonagt.so

# SNMPConf	conf
# SNMPVar	/var/www/snmp" >> /etc/httpd/conf/httpd.conf

#  	echo "add snmp firewall rule if necessary"
# 	if ! grep -q 1610 /etc/sysconfig/iptables ; then
#		sed -ci '/ESTABLISHED\,RELATED/a\
# \# snmp agent for jon\
# -A INPUT -m state --state NEW -m udp -p udp --dport 1610 -j ACCEPT' /etc/sysconfig/iptables
#		if ( grep -q '5\.' /etc/redhat-release ) ; then
#			sed -ci 's/INPUT/RH-Firewall-1-INPUT/g' /etc/sysconfig/iptables
#			echo "replaced with RHEL5 syntax in iptables"
#		fi
# 		service iptables restart
# 	fi

# 	if [ `getenforce` == "Enforcing" ]; then
# 		semanage port -a -t http_port_t -p udp 1600
# 		# semanage port -a -t snmp_port_t -p udp 1610
# 	fi

# 	echo "TODO: download and configure apache response time module"
# 	echo 'see: http://docs.redhat.com/docs/en-US/JBoss_Operations_Network/2.4/html-single/Basic_Admin_Guide/index.html#Apache_Configuration'

# 	service httpd restart
# fi

echo "final cleanup"
rm -rf /usr/local/META-INF/

echo "finally log into jon server and import new server to finish"
echo "note that the jon client won't be importable until DNS entries are created"
) 2>&1 | tee -a $OUT
