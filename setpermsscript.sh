#!/bin/bash

# fail safe if JBOSS_HOME does not evaluate, exit. Otherwise commands may be applied to root directory
if [ ! -d "${JBOSS_HOME}" ]; then
  echo "Exiting. JBOSS_HOME does not exist as a valid directory : $JBOSS_HOME"
	echo "Ensure you are executing the script as bash ./script.sh"
	exit 1
fi

# sets permissions
OUT=$JBOSS_HOME/bin/setperms_$(date +%m%d%Y-%H%M).log
(
DEPLOYGROUP="ACME Deployment TEAM"
DEPLOYFOLDER=/var/tmp/releases/
DEVGROUPS=("ACME Dev Environment - EA" "Vendor Employees")

# echo "in case of daily automation of this script, clean up log files"
# find $JBOSS_HOME/bin/ -maxdepth 1 -mindepth 1 -type f -name "setperms_*.log" -mtime +30 | xargs rm -vr
# until server naming is more consistent and more applications adhere to standards, one will see lots of if/else logic to differentiate permissions

echo "check for required package"
if ! ( rpm -qa | grep -q ^acl- ); then
	yum install -y acl.`uname -p`
fi

echo "determine environment"
echo "will always give developers deployment permissions in all environments except MO and PROD"
TESTENV="1"
if `echo $(hostname -s) | cut -c 1-2 | grep -qi 'P0\|M0' ` ; then
	echo "detected production or model office system in new naming convention"
	TESTENV="0"
elif `echo $(hostname -s) | grep -qi 'PASAPP\|PASAPM' ` ; then
	echo "detected production or model office system in old naming convention"
	TESTENV="0"
fi
# uncomment the below line to override the protection of MO and Prod enviornments
# TESTENV="1"

CUSTOMPORTAL="0"
SPECIALRESTART="0"
BATCHSERVER="0"
if `echo $(hostname -s) | grep -qi SERVER\|STATION' ` ; then
	case `echo $(hostname -s) | tr '[a-z]' '[A-Z]'` in
	SERVERABC|SERVERXYZ)
		echo "cv servers do not need custom portal permissions"
		;;
	SERVER123)
		echo "sow19 batch servers do not need custom portal permissions"
		echo "but they do need vendor development access"
		BATCHSERVER="1"
		;;
	STATION456)
		echo "detected custom portal: liferay (old) and special restart permissions"
		CUSTOMPORTAL="1"
		SPECIALRESTART="1"
		;;
	*)
		echo "detected custom portal: liferay"
		CUSTOMPORTAL="1"
		;;
	esac
fi

### function to setgid and ACLs. usage: jboss_perms <directory> <adgroup> <set_default_acls(bool)> ###
function jboss_perms
{
	mkdir -p $1
	# set group id and give group full access. although this may grant it on unwanted subdirectories (ex: deploy/ROOT.war), acls will prevent unwanted changes
	find -L $1 -type d -exec chmod g+s '{}' \;
	if [[ $3 = "yes" ]]; then
		find -L $1 -type d -exec setfacl -m g:"$2":rwx '{}' \;
		setfacl -R -m d:g:"$2":rwx $1
		find -L $1 -type f -exec setfacl -m g:"$2":rw- '{}' \;
	else
		setfacl -m d:g:"$2":rwx $1
		# setting default ACL doesnt set effective ACL of existing dir, so apply ACL directly to the dir
		setfacl -m g:"$2":rwx $1
		if [[ `basename $1` == "deploy" ]] ; then
			echo "add acls to custom war files/dirs in deploy/"
			for custom in `find -L $1 -mindepth 1 -maxdepth 1 -type f -name "*.war" | grep -v console | grep -v ROOT`; do setfacl -m g:"$2":rw- $custom; done
			for custom in `find -L $1 -mindepth 1 -maxdepth 1 -type d -name "*.war" | grep -v console | grep -v ROOT`; do setfacl -m g:"$2":rwx $custom; find -L $custom/ -type d -exec setfacl -m g:"$2":rwx '{}' \; ; find -L $custom/ -type f -exec setfacl -m g:"$2":rw- '{}' \; ; done
			echo "add acls to custom ear files/dirs in deploy/"
			for custom in `find -L $1 -mindepth 1 -maxdepth 1 -type f -name "*.ear"`; do setfacl -m g:"$2":rw- $custom; done
			for custom in `find -L $1 -mindepth 1 -maxdepth 1 -type d -name "*.ear"`; do setfacl -m g:"$2":rwx $custom; find -L $custom/ -type d -exec setfacl -m g:"$2":rwx '{}' \; ; find -L $custom/ -type f -exec setfacl -m g:"$2":rw- '{}' \; ; done
			# for custom in `find -L $1 -mindepth 1 -maxdepth 1 -type f -name "*.xml"`; do echo "about to set acl on $custom"; setfacl -m g:"$2":rw- $custom; done
		elif echo `basename $1` | grep -qi "conf\|ext" ; then
			echo "add acls to custom config files in conf/"
			for custom in `find -L $1 -mindepth 1 -maxdepth 1 -type f`; do setfacl -m g:"$2":rw- $custom; done
		fi
	fi
}
openumask()
{
	if [ ! x"$1" == "x" ] ; then
		if ( grep -q '5\.' /etc/redhat-release ) ; then
			if ( ! grep -qi "$1" /etc/bashrc ) ; then
				echo "open group write access on umask for group in /etc/bashrc"
				sed -ci "s/id\ -un\`\"\ ]/id\ -un\`\"\ ]\ ||\ [\ \"\`id\ -gn\`\"\ =\ \"$1\"\ ]/" /etc/bashrc
			fi
		elif ( grep -q '6\.' /etc/redhat-release ) ; then
			if ( ! grep -q "umask" /etc/profile ) ; then
				echo "adding umask snippet to /etc/profile"

echo "

# adding umask stanza according to https://access.redhat.com/knowledge/solutions/1372
if [ $UID -gt 199 ] && [ \"\`id -gn\`\" = \"\`id -un\`\" ] || [ \"\`id -gn\`\" = "\"$1\"" ]; then
	umask 002
else
	umask 022
fi
" >> /etc/profile

			elif ( ! grep -qi "$1" /etc/profile ) ; then
				echo "open group write access on umask for group in /etc/profile"
				sed -ci "s/id\ -un\`\"\ ]/id\ -un\`\"\ ]\ ||\ [\ \"\`id\ -gn\`\"\ =\ \"$1\"\ ]/" /etc/profile
			fi
		fi
	fi
}

echo "### reset and configure service control in sudoers ###"
sed -ci '/development/,$d' /etc/sudoers
echo "provide access to jboss service control in /etc/sudoers"
echo "# development and deployment access
Defaults env_keep += "JBOSS_HOME"
Defaults env_keep += "JBOSS_CONF"
Cmnd_Alias JBOSS_CONTROL = /sbin/service jbossas stop, /sbin/service jbossas start, /sbin/service jbossas restart, /sbin/service jbossas status, /sbin/service jbossas dump, /sbin/service jbossas tattle, /sbin/service jbossas help
User_Alias PAS_DEPLOY = %`echo ${DEPLOYGROUP} | sed 's/\ /\\\\\\ /g'`
PAS_DEPLOY $(hostname) = (jboss) NOPASSWD: JBOSS_CONTROL" >> /etc/sudoers

echo "always give development groups access to restart jboss and correct umask"
for (( i = 0 ; i < "${#DEVGROUPS[@]}" ; i++ )) ; do
	GRANTACCESS="1"
	if [[ "${DEVGROUPS[$i]}" == "Vendor Employees" ]] ; then
		echo "be careful which servers vendor can restart jboss on"
		if [[ "${TESTENV}" -eq 0 ]] ; then
			echo "vendor should not have jboss control in non-test environments"
			GRANTACCESS="0"
		fi
		if [[ "${CUSTOMPORTAL}" -eq 0 ]] && [[ "${BATCHSERVER}" -eq 0 ]] ; then
			echo "vendor should not have jboss control in non-batch and non-liferay environments"
			GRANTACCESS="0"
		fi
	fi

	if [[ "${GRANTACCESS}" -eq 1 ]] ; then
		sed -ci "s/User_Alias\ PAS_DEPLOY\ =/User_Alias\ PAS_DEPLOY\ =\ %`echo ${DEVGROUPS[$i]} | sed 's/\ /\\\\\\\ /g'`\,/" /etc/sudoers;
		if [[ "${SPECIALRESTART}" -eq 1 ]] && [[ "${i}" -eq 0 ]] ; then
			sed -ci "s/\ PAS_DEPLOY\ =\ /\ PAS_DEPLOY\ =\ %DocScience,\ /g" /etc/sudoers
		fi
		openumask "${DEVGROUPS[$i]}"
	fi
done

echo "### reset and configure all permissions and access control lists ###"
if [[ "${CUSTOMPORTAL}" -eq 1 ]] ; then
	setfacl -LRbk $JBOSS_HOME/../
else
	setfacl -LRbk $JBOSS_HOME/
fi
setfacl -LRbk "${DEPLOYFOLDER}"
find -L $JBOSS_HOME/server/$JBOSS_CONF/ -type f -exec chmod 0664 '{}' \;
find -L $JBOSS_HOME/server/$JBOSS_CONF/ -type d -exec chmod 0775 '{}' \;
echo "tighten security on password files"
find -L $JBOSS_HOME/server/ -type f -name "*users.properties" -exec chmod -c 440 '{}' \;
find -L $JBOSS_HOME/server/$JBOSS_CONF/deploy/ -mindepth 1 -maxdepth 1 -type f -name "*-ds.xml" -exec chmod -c 440 '{}' \;
if [ -f $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/messaging-jboss-beans.xml ] ; then
	chmod -c 440 $JBOSS_HOME/server/$JBOSS_CONF/deploy/messaging/messaging-jboss-beans.xml
fi

echo "always remove execute access for group other in bin/, use acl for relevant scripts instead"
find $JBOSS_HOME/bin/ -type f -name "*.sh" -exec chmod -c 0774 '{}' \;
for i in classpath.sh probe.sh ; do setfacl -m g:"${DEPLOYGROUP}":r-x $JBOSS_HOME/bin/$i ; done


echo "### configure deployment folder ###"
mkdir -p "${DEPLOYFOLDER}"
# if [ ! -f ${DEPLOYFOLDER}/deploy.sh && ! -f ${DEPLOYFOLDER}/deploy ] ; then
#         echo "create skeleton deploy script for deployment team to finish writing"
#         cat EOF ${DEPLOYFOLDER}/deploy.sh
# #!/bin/bash
# 
# dir=`dirname $0`
# base=`basename $0`
# if [ ! `whoami` = "jboss" ]; then
#         echo "ERROR: must be executed as jboss: sudo -u jboss $dir/$base [release]"
#         exit 1
# 
# 
# env=""
# 
# if [ -z "$1" ]; then
#         echo "Usage: $dir/$base [release]" # rel=REL1-13
#       exit 1
# else
#         rel=$1
# fi
# EOF
# fi
find "${DEPLOYFOLDER}" -type f -name "*.sh" -exec chmod -c 0774 '{}' \;
chgrp -cHLR jboss "${DEPLOYFOLDER}"
find "${DEPLOYFOLDER}"/ -user root -exec chown -cHL jboss '{}' \;
set_default_acls=yes
jboss_perms "${DEPLOYFOLDER}" "${DEPLOYGROUP}" $set_default_acls

find "${DEPLOYFOLDER}" -type f -name "*deploy*" -exec setfacl -m g:"${DEPLOYGROUP}":rwx '{}' \;

echo "### giving deployment group acl rwx access to relevant jboss folders non-recursively ###"
if [ "${CUSTOMPORTAL}" -eq 1 ] ; then
	for dir1 in $JBOSS_HOME/server/$JBOSS_CONF/{deploy,lib/ext,conf}/ ; do
		set_default_acls=no
		jboss_perms "$dir1" "${DEPLOYGROUP}" $set_default_acls
	done
else
	for dir1 in $JBOSS_HOME/server/$JBOSS_CONF/{deploy,conf}/ ; do
		set_default_acls=no
		jboss_perms "$dir1" "${DEPLOYGROUP}" $set_default_acls
	done
fi

echo "### jboss config files ###"
echo "giving deployment group acl rw access to run.conf"
setfacl -m g:"${DEPLOYGROUP}":rw- $JBOSS_HOME/bin/run.conf
echo "giving deployment group acl rw access to datasource xml files in deploy"
find -L $JBOSS_HOME/server/$JBOSS_CONF/deploy/ -mindepth 1 -maxdepth 1 -type f -name "*-ds.xml" -exec setfacl -m g:"${DEPLOYGROUP}":rw- '{}' \;
if [ -f $JBOSS_HOME/server/$JBOSS_CONF/deploy/jboss-web.deployer/server.xml ] ; then
	echo "giving deployment group acl rw access to server.xml (jboss 4)"
	setfacl -m g:"${DEPLOYGROUP}":rw- $JBOSS_HOME/server/$JBOSS_CONF/deploy/jboss-web.deployer/server.xml
elif [ -f $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml ] ; then
	echo "giving deployment group acl rw access to server.xml (jboss eap 5)"
	setfacl -m g:"${DEPLOYGROUP}":rw- $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml
fi
echo "giving development group full access to logs/"
jboss_perms $JBOSS_HOME/server/$JBOSS_CONF/logs/ "${DEPLOYGROUP}" yes

openumask "${DEPLOYGROUP}"

if [[ "${CUSTOMPORTAL}" -eq 1 ]] ; then
	echo "### grant permissions to custom portal provider: liferay ###"
	echo "giving deployment group acl rwx access to main lib folders"
	for dir1 in $JBOSS_HOME/{..,common/lib,server/$JBOSS_CONF/lib}/ ; do
		set_default_acls=no
		jboss_perms "$dir1" "${DEPLOYGROUP}" $set_default_acls
	done
	mkdir -p $JBOSS_HOME/../{deploy,data}/
	chown -cR jboss:jboss $JBOSS_HOME/../{deploy,data}/
	if [ -d $JBOSS_HOME/../deploy/ ] ; then
		echo "giving deployment group acl rwx access to third party deploy folder and ROOT.war"
		set_default_acls=no
		jboss_perms "$JBOSS_HOME/../deploy/" "${DEPLOYGROUP}" $set_default_acls
		for dir1 in $JBOSS_HOME/server/$JBOSS_CONF/deploy/ROOT.war/ ; do
			set_default_acls=yes
			jboss_perms "$dir1" "${DEPLOYGROUP}" $set_default_acls
		done
	fi
	echo "giving deployment group acl rw access to deploy/mail-service.xml"
	find -L $JBOSS_HOME/server/$JBOSS_CONF/deploy/ -mindepth 1 -maxdepth 1 -type f -name "mail-service.xml" -exec setfacl -m g:"${DEPLOYGROUP}":rw- '{}' \;
fi

echo "### developer permissions ###"
if [[ "${TESTENV}" -eq 1 ]] ; then
	for (( i = 0; i < ${#DEVGROUPS[@]}; i++ )) ; do
		if [[ "${DEVGROUPS[$i]}" == "Vendor Employees" ]] && [[ "${CUSTOMPORTAL}" -eq 0 ]] && [[ "${BATCHSERVER}" -eq 0 ]] ; then
			echo "Vendor Employees only need access to liferay and batch servers"
			break;
		fi
		echo "give development group(s) acl rwx access to relevant jboss folders non-recursively"
		if [ "${CUSTOMPORTAL}" -eq 1 ] ; then
			for dir1 in $JBOSS_HOME/server/$JBOSS_CONF/{deploy,lib/ext,conf}/ ; do
				set_default_acls=no
				jboss_perms "$dir1" "${DEVGROUPS[$i]}" $set_default_acls
			done
		else
			for dir1 in $JBOSS_HOME/server/$JBOSS_CONF/{deploy,conf}/ ; do
				set_default_acls=no
				jboss_perms "$dir1" "${DEVGROUPS[$i]}" $set_default_acls
			done
		fi

		echo "give development group(s) access to deployment folder"
		for dir1 in "${DEPLOYFOLDER}" ; do
			set_default_acls=yes
			jboss_perms "$dir1" "${DEVGROUPS[$i]}" $set_default_acls
		done
		find "${DEPLOYFOLDER}" -type f -name "*deploy*" -exec setfacl -m g:"${DEVGROUPS[$i]}":r-x '{}' \;

		echo "### jboss config files ###"
		echo "giving development group acl rw access to run.conf"
		setfacl -m g:"${DEVGROUPS[$i]}":rw- $JBOSS_HOME/bin/run.conf
		echo "giving development group acl rw access to datasource xml files in deploy"
		find -L $JBOSS_HOME/server/$JBOSS_CONF/deploy/ -mindepth 1 -maxdepth 1 -type f -name "*-ds.xml" -exec setfacl -m g:"${DEVGROUPS[$i]}":rw- '{}' \;
		if [ -f $JBOSS_HOME/server/$JBOSS_CONF/deploy/jboss-web.deployer/server.xml ] ; then
			echo "giving development group acl rw access to server.xml (jboss 4)"
			setfacl -m g:"${DEVGROUPS[$i]}":rw- $JBOSS_HOME/server/$JBOSS_CONF/deploy/jboss-web.deployer/server.xml
		elif [ -f $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml ] ; then
			echo "giving development group acl rw access to server.xml (jboss eap 5)"
			setfacl -m g:"${DEVGROUPS[$i]}":rw- $JBOSS_HOME/server/$JBOSS_CONF/deploy/jbossweb.sar/server.xml
		fi

		if [[ "${CUSTOMPORTAL}" -eq 1 ]] ; then
			echo "### grant permissions to custom portal provider: liferay ###"
			echo "giving development group acl rwx access to main lib folders"
			for dir1 in $JBOSS_HOME/{..,common/lib,server/$JBOSS_CONF/lib}/ ; do
				set_default_acls=no
				jboss_perms "$dir1" "${DEVGROUPS[$i]}" $set_default_acls
			done
			if [ -d $JBOSS_HOME/../deploy/ ] ; then
				echo "giving development group acl rwx access to third party deploy folder and ROOT.war"
				set_default_acls=no
				jboss_perms "$JBOSS_HOME/../deploy/" "${DEVGROUPS[$i]}" $set_default_acls
				for dir1 in $JBOSS_HOME/server/$JBOSS_CONF/{logs,deploy/ROOT.war}/ ; do
					set_default_acls=yes
					jboss_perms "$dir1" "${DEVGROUPS[$i]}" $set_default_acls
				done
			fi
			echo "giving development group acl rw access to deploy/mail-service.xml"
			find -L $JBOSS_HOME/server/$JBOSS_CONF/deploy/ -mindepth 1 -maxdepth 1 -type f -name "mail-service.xml" -exec setfacl -m g:"${DEVGROUPS[$i]}":rw- '{}' \;
		fi
	done
fi

echo "do not change all files to default user/group as this will remove traceability"
# chown -HLR jboss:jboss $JBOSS_HOME/
# chgrp -cHLR jboss $JBOSS_HOME/
echo "change ownership of any files owned by root"
find $JBOSS_HOME/ -user root -exec chown -cHL jboss '{}' \;
find $JBOSS_HOME/ -group root -exec chgrp -cHL jboss '{}' \;
) 2>&1 | tee -a $OUT
