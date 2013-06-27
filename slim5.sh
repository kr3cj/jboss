#!/bin/bash

# fail safe if JBOSS_HOME does not evaluate, exit. Otherwise commands may be applied to root directory
if [ ! -d "$JBOSS_HOME" ]; then
 echo "Exiting. JBOSS_HOME does not exist as a valid directory : $JBOSS_HOME"
 echo "Try executing the script as bash ./script.sh"
 exit 1
fi

cd $JBOSS_HOME/server/
OUT=slim_${JBOSS_CONF}_$(date +%m%d%Y-%H%M).log
(

echo "
### slim jboss eap/ewp 5.x ###"
echo "dependencies are automatically retained"
echo "see http://community.jboss.org/wiki/JBoss5xTuningSlimming or page 283 of JB336"
echo " or https://access.redhat.com/kb/docs/DOC-49333"
echo " or https://access.redhat.com/sites/default/files/slimtrimpruneeap.pdf"
 
SLIM_AJP=${1}
SLIM_BSHDEPLOYER=${2}
SLIM_CLUSTER=${3}
SLIM_DATASOURCE=${4}
SLIM_EJB2=${5}
SLIM_EJB3=${6}
SLIM_HOT=${7}
SLIM_HYPER=${8}
SLIM_IIOP=${9}
SLIM_INVOKER_HTTP=${10}
SLIM_INVOKER_IIOP=${11}
SLIM_INVOKER_JMX=${12}
SLIM_INVOKER_LEGACYJRMP=${13}
SLIM_INVOKER_POOLED=${14}
SLIM_JCA=${15}
SLIM_JUDDI=${16}
SLIM_KEYGENUUID=${17}
SLIM_MAIL=${18}
SLIM_MANAGEMENT=${19}
SLIM_MESSAGING=${20}
SLIM_PROFILESERVICE=${21}
SLIM_PROPERTIESSERVICE=${22}
SLIM_REMOTING=${23}
SLIM_SCHEDULER=${24}
SLIM_SEAM=${25}
SLIM_SNMP=${26}
SLIM_TRANSACTION=${27}
SLIM_WEB=${28}
SLIM_WSCLIENT=${29}
SLIM_WSSERVER=${30}
SLIM_XNIO=${31}

function disableport()
{
  if [ $1 -gt 0 ] ; then
		NUM1=0
		NUM1=`grep -n $1 /etc/sysconfig/iptables | cut -d ":" -f1`
		if [ -n "${NUM1}" ] && [ "${NUM1}" -gt 0 ] ; then
			sed -ci "${NUM1}s/^-A\ /\#\ -A\ /" /etc/sysconfig/iptables
			echo "disabled port $1"
		else
			echo "unable to find port $1 in iptable rules"
		fi
	fi
}
remove()
{
	if [ ! x"$1" == "x" ] ; then
		if [ -f $1 ] ; then
			rm -vf $1
		elif [ -d $1 ] ; then
			rm -vrf $1
		else
			echo "oops, cannot find $1 to remove it"
		fi
	fi
}

if [[ "${SLIM_AJP}" -eq 1 ]] ; then
	echo "
### slim ajp connector ###"
	NUM1=`grep -n "AJP 1.3 Connector" $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml | cut -d ":" -f1`
	NUM2=$((${NUM1}+2))
	sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml

	disableport 8009
fi
 
if [[ "${SLIM_BSHDEPLOYER}" -eq 1 ]] ; then
	echo "
### slim bean shell deployer ### (eap only)"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/bsh.deployer/
fi
 
if [[ "${SLIM_CLUSTER}" -eq 1 ]] ; then
	echo "
### slim cluster ###"
	echo "DEPRECATED; copy from default node instead"

# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy-hasingleton/
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/farm/
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/cluster/
# 
# 	sed -ci 's/StaticClusteredProfileFactory/repository.StaticProfileFactory/g' $JBOSS_HOME/server/$JBOSS_CONF/conf/bootstrap/profile.xml
# 	echo "comment out farmURIs property"
# 	NUM1=`grep -n farmURIs $JBOSS_HOME/server/$JBOSS_CONF/conf/bootstrap/profile.xml | cut -d ":" -f1`
# 	NUM2=$((${NUM1}+4))
# 	sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/conf/bootstrap/profile.xml
# 
# 	echo "TEST: eap only (unless already slimmed)"
# 	for i in `find -L $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/ -mindepth 1 -maxdepth 1 -type f -name "*-persistence-service.xml"`; do sed -ci 's/<attribute\ name=\"Clustered\">true<\/attribute>/<attribute\ name=\"Clustered\">false<\/attribute>/' $i; sed -ci '/jboss.jgroups\:service=ChannelFactory/d' $i; done
# 	echo "replace text"
# 	sed -ci 's/<attribute\ name=\"Clustered\">true<\/attribute>/<attribute\ name=\"Clustered\">false<\/attribute>/' 
# 
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/httpha.invoker.sar/
# 	cp -ar $JBOSS_HOME/server/default/deploy/http.invoker.sar/ $JBOSS_HOME/server/$JBOSS_CONF/deploy
# 
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/deployers/clustering-deployer-jboss-beans.xml 
# 	cp -a $JBOSS_HOME/server/default/deployers/clustering-deployer-jboss-beans.xml $JBOSS_HOME/server/$JBOSS_CONF/deploy/deployers
# 	echo "in deployers/clustering-deployer-jboss-beans.xml, comment out WebAppClusteringDependencyDeployer"
# 	# NUM1=`grep -n WebAppClusteringDependencyDeployer $JBOSS_HOME/server/$JBOSS_CONF/deployers/clustering-deployer-jboss-beans.xml | cut -d ":" -f1`
# 	# NUM2=$((${NUM1}+6))
# 	# sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/deployers/clustering-deployer-jboss-beans.xml
# 
# 	# additional differences detected between default and production
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/deploy.last/
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/deploy-hasingleton/
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/production/lib/{hibernate-jbosscache2.jar,jacorb.jar,jbosscache-core.jar,jboss-cache-pojo.jar,jcip-annotations.jar,jgroups.jar}
# 	sed -ci 's/property\ name="debug">false/property\ name="debug">true/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/jca-jboss-beans.xml
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/iiop-service.xml
# 	sed -ci 's/<property name="scanPeriod">5000/<property name="scanPeriod">60000/' $JBOSS_HOME/server/$JBOSS_CONF/deploy/hdscanner-jboss-beans.xml
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/snmp-adaptor.sar/
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/juddi-service.sar/
# 	sed -ci 's<attribute\ name="DownloadServerClasses">false/<attribute\ name="DownloadServerClasses">true/' $JBOSS_HOME/server/$JBOSS_CONF/conf/jboss-service.xml
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/ejb3.deployer/META-INF/ejb3-iiop-deployers-jboss-beans.xml
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/farm/cluster-examples-service.xml
# 	remove $JBOSS_HOME/server/$JBOSS_CONF/conf/jacorb.properties

	for i in 4447 4448 54200 54201 1100 1101 ; do disableport $i ; done
fi
 
if [[ "${SLIM_DATASOURCE}" -eq 1 ]] ; then
	echo "
### slim datasource ###"
	if [[ "${SLIM_MESSAGING}" -eq 1 && "${SLIM_JUDDI}" -eq 1 && "${SLIM_KEYGENUUID}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/hsqldb-ds.xml
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jboss-local-jdbc.jar
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jboss-xa-jdbc.rar/
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/sqlexception-service.xml
	else
		echo "retained datasource as messaging, juddi and keygen uuid need it"
	fi
fi

if [[ "${SLIM_EJB2}" -eq 1 ]] ; then
	echo "
### slim ejb2 ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-container-jboss-beans.xml

	if [[ "${SLIM_PROFILESERVICE}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/ejb-deployer-jboss-beans.xml
	else
		echo "retained ejb-deployer-jboss-beans.xml as the profile service needs it"
	fi

	if [[ "${SLIM_EJB3}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml
	else
		echo "retained ejb2-timer-service.xml as EJB3 needs it"
	fi
fi

if [[ "${SLIM_EJB3}" -eq 1 ]] ; then
	echo "
### slim ejb3 ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb3-connectors-jboss-beans.xml
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb3-container-jboss-beans.xml
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb3-interceptors-aop.xml
	if [[ "${SLIM_DATASOURCE}" -eq 1 && "${SLIM_EJB2}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb3-timerservice-jboss-beans.xml
	else
		echo "retained ejb3 timer as transaction needs it"
	fi
	if [[ "${SLIM_WEB}" -eq 1 && "${SLIM_WSSERVER}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/jboss-ejb3-endpoint-deployer.jar
		remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/jboss-ejb3-metrics-deployer.jar
		remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/ejb3-deployers-jboss-beans.xml
		remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/ejb3.deployer/
	else
		echo "retained ejb3 deployers as jboss web and web services need it"
	fi

	echo "add to the WarDeployer bean block"
	NUM1=`grep -n org.jboss.web.tomcat.service.deployers.TomcatDeployer $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossweb.deployer/META-INF/war-deployers-jboss-beans.xml | cut -d ":" -f1`
	NUM1=$((${NUM1}+1))
	sed -ci "${NUM1}i\ \ \ \ \ \ <property name="persistenceUnitDependencyResolver"><null/></property>" $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossweb.deployer/META-INF/war-deployers-jboss-beans.xml
	disableport 3873
fi
 
if [[ "${SLIM_HOT}" -eq 1 ]] ; then
	echo "
### slim hot deployment ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/hdscanner-jboss-beans.xml
fi
 
if [[ "${SLIM_HYPER}" -eq 1 ]] ; then
	echo "
### slim hypersonic database ###"
	echo "see https://access.redhat.com/kb/docs/DOC-37157"
	if [[ "${SLIM_MESSAGING}" -eq 1 && "${SLIM_JUDDI}" -eq 1 && "${SLIM_KEYGENUUID}" -eq 1 ]] ; then
		echo "safe to remove hypersonic and all components that use it"
		if [ -f $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml ] ; then
			echo "change ejb timer persistence policies"

			echo "1 - uncomment noop policy"
			NUM1=`grep -n "persistencePolicy=noop" $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml | cut -d ":" -f1`
			NUM1=$((${NUM1}-1))
			NUM2=$((${NUM1}+1))
			sed -ci "${NUM1}d" $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml
			sed -ci "${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml

			echo "2 - change persistence policy attribute of ejbtimerservice"
			sed -ci 's/database</noop</g' $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml

			echo "3 - delete persistencePolicy=database mbean"
			NUM1=`grep -n "org.jboss.ejb.txtimer.DatabasePersistencePolicy" $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml | cut -d ":" -f1`
			NUM2=$((${NUM1}+8))
			sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml
		fi

		if [ -f $JBOSS_HOME/server/$JBOSS_CONF/deploy/snmp-adaptor.sar/attributes.xml ] ; then
			echo "delete the DefaultDS ManagedConnectionPool mbean"
			NUM1=`grep -n "ManagedConnectionPool" $JBOSS_HOME/server/$JBOSS_CONF/deploy/snmp-adaptor.sar/attributes.xml | cut -d ":" -f1`
			NUM2=$(({NUM1}+4))
			sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/deploy/snmp-adaptor.sar/attributes.xml
		fi
	else
		echo "cannot remove hypersonic, must effectively disable it"

		echo "eap only: replace jms persistence manager service"
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/hsqldb-persistence-service.xml
		cp $JBOSS_HOME/docs/examples/jms/mssql-persistence-service.xml $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/

		# echo "find anything that uses DefaultDS and change it ???"
		# for i in `grep DefaultDS `find $JBOSS_HOME/server/$JBOSS_CONF/ -type f -name "*.xml"` | cut -d ":" -f1 `; do 
			# sed -ci 's/DefaultDS/OtherDS/g' $i
		# done

		if [[ "${SLIM_CLUSTER}" -eq 1 ]] ; then
			echo "see https://access.redhat.com/knowledge/node/19766"
			sed -ci '/jboss.jgroups:service=ChannelFactory/d' $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/mssql-persistence-service.xml	
		fi
	fi
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/hsqldb-ds.xml
fi
 
if [[ "${SLIM_IIOP}" -eq 1 ]] ; then
	echo "
### slim iiop ### (eap/production node only)"
	echo "iiop is required to support Common Object Request Broker Architecture (CORBA) clients"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/iiop-service.xml

	remove $JBOSS_HOME/server/$JBOSS_CONF/conf/jacorb.properties
	remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/ejb3.deployer/META-INF/ejb3-iiop-deployers-jboss-beans.xml
	remove $JBOSS_HOME/server/$JBOSS_CONF/lib/jacorb.jar
	sed -ci 's/org.jboss.iiop.naming.ORBInitialContextFactory/org.jnp.interfaces.NamingContextFactory/g' $JBOSS_HOME/server/$JBOSS_CONF/conf/jndi.properties

	disableport 3528
fi
 
if [[ "${SLIM_INVOKER_HTTP}" -eq 1 ]] ; then
	echo "
### slim http invoker ### (eap only)"
	if [[ "${SLIM_CLUSTER}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/httpha-invoker.sar/
	else
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/http-invoker.sar/
	fi
fi

if [[ "${SLIM_INVOKER_IIOP}" -eq 1 ]] ; then
	echo "
### slim iiop invoker ###"
	echo "iiop invoker"
	NUM1=`grep -n "<name>iiop</name>" $JBOSS_HOME/server/$JBOSS_CONF/conf/standardjboss.xml | cut -d ":" -f1`
	NUM1=$((${NUM1}-1))
	NUM2=$((${NUM1}+12))
	sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/conf/standardjboss.xml
fi

if [[ "${SLIM_INVOKER_JMX}" -eq 1 ]] ; then
	echo "
### slim jmx invoker ###"
	if [[ "${SLIM_MANAGEMENT}" -eq 1 ]] ; then
		echo "jmx invoker: must keep it for shutdown script"
		echo "must also keep it so rhq-agent can import jboss monitoring info for Applications, Resources, and Service Binding Manager"
		# remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jmx-invoker-service.xml
	else
		echo "retained jmx invoker as management needs it"
	fi
fi

if [[ "${SLIM_INVOKER_LEGACYJRMP}" -eq 1 ]] ; then
	echo "
### slim rmi/jrmp/legacy invoker ###"
	if [[ "${SLIM_INVOKER_JMX}" -eq 1 ]] ; then
		echo "never remove rmi/legacy/jrmp invoker as rhq-agent needs it to import JVM information"
		# NUM1=`grep -n .JRMPInvoker $JBOSS_HOME/server/$JBOSS_CONF/deploy/legacy-invokers-service.xml | cut -d ":" -f1`
		# NUM2=$((${NUM1}+15))
		# sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/deploy/legacy-invokers-service.xml
	
		# disableport 4444
	else
		echo "retained rmi/legacy/jrmp invoker as jmx invoker needs it"
	fi
fi

if [[ "${SLIM_INVOKER_POOLED}" -eq 1 ]] ; then
	echo "
### slim pooled invoker ###"
	echo "provides remote connections for ejb"
	echo "pooled invoker"
	NUM1=`grep -n .PooledInvoker $JBOSS_HOME/server/$JBOSS_CONF/deploy/legacy-invokers-service.xml | cut -d ":" -f1`
	NUM2=$((${NUM1}+26))
	sed -ci "${NUM1},${NUM2}d" $JBOSS_HOME/server/$JBOSS_CONF/deploy/legacy-invokers-service.xml

	disableport 4445
fi

if [[ "${SLIM_JCA}" -eq 1 ]] ; then
	echo "
### slim jca ###"
	if [[ "${SLIM_EJB2}" -eq 1 && "${SLIM_EJB3}" -eq 1 && "${SLIM_DATASOURCE}" -eq 1 && "${SLIM_MESSAGING}" -eq 1 ]] ; then
		echo "always retain JCA"
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jca-jboss-beans.xml
	else
		echo "retained jca as ejb, datasource and messaging need it"
	fi
fi

if [[ "${SLIM_JUDDI}" -eq 1 ]] ; then
	echo "
### slim juddi ### (eap/production node only)"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/juddi-service.sar/
fi
 
if [[ "${SLIM_KEYGENUUID}" -eq 1 ]] ; then
	echo "
### slim keygen ### (eap only)"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/uuid-key-generator.sar/
fi
 
if [[ "${SLIM_MAIL}" -eq 1 ]] ; then
	echo "
### slim mail ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/mail-service.xml
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/mail-ra.rar/
fi
 
if [[ "${SLIM_MANAGEMENT}" -eq 1 ]] ; then
	echo "
### slim management ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/admin-console.war/
	echo "do not remove jmx-console"
	# remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jmx-console.war/
	echo "do not remove root console"
	# remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ROOT.war/

	echo "eap only"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/management/
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/monitoring-service.xml
fi

if [[ "${SLIM_MESSAGING}" -eq 1 ]] ; then
	echo "
### slim messaging/jms ###"
	# retain these?
	remove $JBOSS_HOME/server/$JBOSS_CONF/conf/props/messaging-roles.properties
	remove $JBOSS_HOME/server/$JBOSS_CONF/conf/props/messaging-users.properties

	echo "eap only"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jms-ra.rar/
	# remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/quartz-ra.rar/ # moved to scheduler section
	remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/messaging-definitions-jboss-beans.xml

	echo "see second known issue at bottom of jboss eap 5.x install document"
	sed -ci 's/<property\ name="com.arjuna.ats.jta.recovery.XAResourceRecovery.JBMESSAGING1"/<!--\ property\ name="com.arjuna.ats.jta.recovery.XAResourceRecovery.JBMESSAGING1"/' $JBOSS_HOME/server/$JBOSS_CONF/conf/jbossts-properties.xml
	sed -ci 's/value="org.jboss.jms.server.recovery.MessagingXAResourceRecovery;java:\/DefaultJMSProvider"\/>/value="org.jboss.jms.server.recovery.MessagingXAResourceRecovery;java:\/DefaultJMSProvider"\/\ -->/' $JBOSS_HOME/server/$JBOSS_CONF/conf/jbossts-properties.xml

	for i in 7900 57900 53200 4457 43830 ; do disableport $i ; done
fi
 
if [[ "${SLIM_PROFILESERVICE}" -eq 1 ]] ; then
	echo "
### slim profile service ###"
	if [[ "${SLIM_INVOKER_JMX}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/profileservice-jboss-beans.xml
	else
		echo "retained profile service as jmx invoker needs it?"
	fi
fi

if [[ "${SLIM_PROPERTIESSERVICE}" -eq 1 ]] ; then
	echo "
### slim properties service ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/properties-service.xml
fi

if [[ "${SLIM_REMOTING}" -eq 1 ]] ; then
	echo "
### slim remoting ###"
	if [[ "${SLIM_PROFILESERVICE}" -eq 1 ]] ; then
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/remoting-jboss-beans.xml
		disableport 4446

		echo "keep jmx-remoting for visualvm troubleshooting?"
		# remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jmx-remoting.sar/
		# disableport 9001
	else
		echo "retained remoting as profile service needs it"
	fi 
fi

if [[ "${SLIM_SCHEDULER}" -eq 1 ]] ; then
	echo "
### slim schedule ### (eap only)"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/schedule-manager-service.xml
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/scheduler-service.xml

# 	echo "special logic: ejb3 timer service is dependent on ejb2 timer service"
# 	if [[ "${SLIM_EJB3}" -eq 1 && "${SLIM_EJB2}" -eq 1 ]] ; then
# 		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb3-timerservice-jboss-beans.xml
# 		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb2-timer-service.xml
# 	elif [[ "${SLIM_EJB3}" -eq 1 && "${SLIM_EJB2}" -eq 0 ]] ; then
# 		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/ejb3-timerservice-jboss-beans.xml
#	fi
fi
 
if [[ "${SLIM_SEAM}" -eq 1 ]] ; then
	echo "
### slim seam ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/seam.deployer/
fi

if [[ "${SLIM_SNMP}" -eq 1 ]] ; then
	echo "
### slim snmp adaptor ### (eap/production node only)"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/snmp-adaptor.sar/
fi
 
if [[ "${SLIM_TRANSACTION}" -eq 1 ]] ; then
	echo "
### slim transaction ###"
	if [[ "${SLIM_EJB3}" -eq 1 && "${SLIM_WEB}" -eq 1 ]] ; then
		echo "transaction service"
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/transaction-jboss-beans.xml
		remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/transaction-service.xml
		
		for i in 4712 4713 ; do disableport $i ; done
	else
		echo "retained transaction as EJB3 and web need it"
	fi
fi
 
if [[ "${SLIM_WEB}" -eq 1 ]] ; then
	echo "
### slim web connector ###"
	if [[ "${SLIM_WSSERVER}" -eq 1 ]] ; then
		echo "not recommended"
		# remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/
		# remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossweb.deployer/
		
		# for i in 8080 8443 ; do disableport $i ; done
	else
		echo "retained web as web services need it"
	fi
fi

if [[ "${SLIM_WSSERVER}" -eq 1 ]] ; then
	echo "
### slim all web service client and hosting files ###"
	remove $JBOSS_HOME/server/$JBOSS_CONF/conf/jax-ws-catalog.xml
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossws.sar/
	remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossws.deployer/
	
	# retain these?
	remove $JBOSS_HOME/server/$JBOSS_CONF/conf/props/jbossws-roles.properties
	remove $JBOSS_HOME/server/$JBOSS_CONF/conf/props/jbossws-users.properties
	
	disableport 8083
	if [[ "${SLIM_WSCLIENT}" -eq 0 ]] ; then
		echo "
### unslim web service client files ###"
		mkdir -p $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossws.deployer/META-INF/
		for jar in FastInfoset.jar jbossws-common.jar jbossws-native-core.jar wsdl4j.jar xmlsec.jar; do cp -av $JBOSS_HOME/server/production/deployers/jbossws.deployer/$jar $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossws.deployer/; done
		cp -av $JBOSS_HOME/server/production/deployers/jbossws.deployer/META-INF/standard-jaxws-client-config.xml $JBOSS_HOME/server/$JBOSS_CONF/deployers/jbossws.deployer/META-INF/
	fi
fi

if [[ "${SLIM_XNIO}" -eq 1 ]] ; then
	echo "
### slim xnio ### (eap only)"
	remove $JBOSS_HOME/server/$JBOSS_CONF/deployers/xnio.deployer/
	remove $JBOSS_HOME/server/$JBOSS_CONF/deploy/xnio-provider.jar/
fi

echo "
### finally, remove minimal, web, all and standard nodes ###"
for i in minimal web all standard; do find -L $JBOSS_HOME/server/$i | xargs rm -r 2> /dev/null; done;
if [[ "${SLIM_CLUSTER}" -eq 1 ]] ; then
find -L $JBOSS_HOME/server/production | xargs rm -r 2> /dev/null;
else
find -L $JBOSS_HOME/server/default | xargs rm -r 2> /dev/null;
fi
echo "
### remove mod_cluster, picketlink, resteasy, and seam folders ###"
rm -rf $JBOSS_HOME/../{mod_cluster,picketlink,resteasy,seam}/
echo "
### remove doc folder ###"
rm -rf $JBOSS_HOME/docs/
echo "
### do not remove client/ folder as it would prevent jon monitoring ###"
# remove $JBOSS_HOME/client/
# jon monitoring requires:
# bin/run.jar
# client/javassist.jar, jbossall-client.jar, trove.jar
# common/lib/jboss-security-aspects.jar
# lib/jboss-dependency.jar, jboss-main.jar, jboss-managed.jar, jboss-metatype.jar, jboss-system.jar
echo "
### remove copyright.txt, jar-versions.xml, JBossEULA.txt and lgpl.html ###"
remove $JBOSS_HOME/{copyright.txt,jar-versions.xml,JBossEULA.txt,lgpl.html}

) 2>&1 | tee -a $OUT
