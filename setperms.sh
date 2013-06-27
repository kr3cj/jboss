#!/bin/bash
echo "this script will download and run the latest version of setpermsscript.sh"
echo "it can only be run by server administrators and utilizes granular acl permissions for jboss administration"
echo "documentation on the permissions available are detailed at PasLinuxPermissions.xls in the J2EE folder on sharepoint"

# fail safe if JBOSS_HOME does not evaluate, exit. Otherwise commands may be applied to root directory
if [ ! -d "$JBOSS_HOME" ]; then
 echo "Exiting. JBOSS_HOME does not exist as a valid directory : $JBOSS_HOME"
 echo "Try executing the script as bash ./script.sh"
 exit 1
fi

if [[ -z ${#ENV} ]] ; then
  echo "detected standalone mode, must reset variables"
	KICKSTART_HOST=server1.example.com
fi
wget -nv http://${KICKSTART_HOST}/jboss_files/jboss/setpermsscript.sh --output-document=$JBOSS_HOME/bin/setpermsscript.sh
bash $JBOSS_HOME/bin/setpermsscript.sh
rm $JBOSS_HOME/bin/setpermsscript.sh
