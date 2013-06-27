jboss
=====

JBoss scripts and artifacts

authors: Corey Taylor, RHCE
had some initial help from Dustin Black, RHCA, particularly on setpermsscript.sh
date: 2/2011-current
summary: jboss eap 5.x install script for RHEL kickstart
description: installs, tunes, slims, and secures a supported and enterprise ready instance of JBoss EAP or EWP 5.1.x on Red Hat Enterprise Linux; also installs monitoring agent and backup job; mechanically enforce all standards wherever possible
prerequisites:
* store all install media on a file server ${KICKSTART_HOST} shared via apache (ex: jboss-eap-5.x.x.zip)
* correctly configure cobbler server to call this script as an "include" not a snippet (will not correctly compile)
prebuild customized files and store at http://${KICKSTART_HOST}/jboss_files/jboss/prebuilt5/
* jboss_init_redhat.sh
* mssql-ds.xml (generic but comprehensive)
* jboss-log4j.xml
prebuild install scripts
* slim5.sh at http://${KICKSTART_HOST}/jboss_files/jboss/
* tunejvm.sh at http://${KICKSTART_HOST}/jboss_files/jboss/
* rhq-agent-install.sh at http://${KICKSTART_HOST}/jon/rhq-agent-install.sh
* setperms.sh, setpermsscript.sh at http://${KICKSTART_HOST}/jboss_files/jboss/
assumptions
* you have 2 different rhq monitor servers based on datacenter environment
* you have 1 deployment group and multiple development groups
* environment and purpose can be inferred from the hostname
* BACKUP_SERVER variable is for NFS, not CFS
references
* Java App Server Request Form and TMNAS J2EE Support Standards: https://docs.google.com/spreadsheet/viewform?key=0AiZ3fCT4e0KLdFpVVnJSdmQwQnVsUE84cmdpWkJ6cWc&hl=en_US&gridId=0
TODO
* smarter sed xml manipulation (sed -ci '/uncommentfromhere/,/uncommenttohere/d' /path/to/file instead of deleting 10 lines)
* clustering work
* check for existence of action before performing action (does file exist, does section exist)
