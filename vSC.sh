#!/bin/bash
#
# Script (validateSSLCerts.sh) to validate Lets Encrypt SSL Certifications for Synology NAS's
#
# Version 0.0.2b - Copyright (c) 2018 by Matt Carlotta
#
# Introduction:
#     - validateSSLCerts (vSC) is an automated bash script that attempts to validate and
#        update Lets Encrypt SSL Certifications for Synology NAS's running
#        sameersbn/docker-gitlab container
#
#
# Bugs:
#     - Bug reports can be filed at: https://github.com/mattcarlotta/validateSSLCerts/issues
#        Please provide clear steps to reproduce the bug and the output of the
#        script. Thank you!
#

#===============================================================================##
## TODO                                                                          #
##==============================================================================##
# 1. Add commands to overwrite global variables
# 2. Update README with instructions
# 3. Research if Synology NAS autorenews invalidated certs; if not, research how to force renew after X days before


#===============================================================================##
## GLOBAL VARIABLES                                                              #
##==============================================================================##
#/usr/syno/etc/certificate/_archive/

# gitlab container path
gitlabPath="/volume1/docker/personal/gitlab"

# gitlab data certificates path
#gCertPath="/home/m6d/Documents/gitlabCerts" # local
gCertPath="$gitlabPath"/gitlab/data/certs # remote

# lets encrypt certifications path
#gLetsEncryptPath="/opt/validateSSLCerts" #local
gLetsEncryptPath="/usr/syno/etc/certificate/_archive/0rOTRe" # remote

# gitlab data certificates log path
gLogPath="$gCertPath"/validate_cert.log

# amount of days to check cert against (will expire in X days?)
gCertExpireDays=7

# max log file size in bytes
#gLogMaxSize=1000 # local (1kb)
#gLogMaxSize=10000 # local (10kb)
gLogMaxSize=10000000 # remote (10mb)

# current date
gCurrentDate=$(/bin/date +"%m/%d/%Y")

# current time
gCurrentTime=$(/bin/date +"%I:%M %p")


#===============================================================================##
## END SESSION #
##==============================================================================##
function _end_session()
{
	printf "%s------------------------------------------ END OF SESSION -------------------------------------------\n\n" 																																	>> "$gLogPath"
}


#===============================================================================##
## ABORT SESSION  -- PRINTS MESSAGES TO gLogPath AND EXITS SCRIPT                #
##==============================================================================##
function _abort_session()
{
	message=$1
	printf "$gCurrentTime -- $message\n" 																																																			>> "$gLogPath"
	printf "$gCurrentTime -- Aborting session.\n" 																																																			>> "$gLogPath"
	_end_session
	exit 1
}


#===============================================================================##
## CREATE NEW CERTS -- CREATES NEW LETS ENCRYPT CERTIFICATIONS FOR GITLAB        #
##==============================================================================##
function _create_new_certs()
{
	cat "$gLetsEncryptPath"/privkey.pem > "$gCertPath"/gitlab.key |\
	cat "$gLetsEncryptPath"/cert.pem "$gLetsEncryptPath"/fullchain.pem > "$gCertPath"/gitlab.crt |\
	cat "$gLetsEncryptPath"/cert.pem > "$gCertPath"/cert.pem
	chown 1000:1000 "$gCertPath"/gitlab.key "$gCertPath"/gitlab.crt "$gCertPath"/cert.pem
	printf "$gCurrentTime -- Added some new certificates to $gCertPath. \n" 																																																						>> "${gLogPath}"
}


#===============================================================================##
## REMOVE OLD CERTS -- REMOVES LETS ENCRYPT CERTS FROM GITLAB FOLDER             #
##==============================================================================##
function _remove_old_certs()
{
	if [ ! -f "$gCertPath"/cert.pem ] || [ ! -f "$gCertPath"/gitlab.key ] || [ ! -f "$gCertPath"/gitlab.key ];
	then
	_abort_session "Unable to locate your current certifications in $gCertPath."
	fi

	rm "$gCertPath"/cert.pem "$gCertPath"/gitlab.key "$gCertPath"/gitlab.crt > /dev/null 2>&1
	if [[ $? -ne 0 ]];
	then
	_abort_session "Unable to remove your current certifications."
	fi
	printf "$gCurrentTime -- Removed the old certificates from $gCertPath. \n" 																																																							>> "$gLogPath"
}


#===============================================================================##
## RESTART GITLAB CONTAINER -- RESTARTS GITLAB CONTAINER TO USE NEW CERTS        #
##==============================================================================##
function _restart_gitlab_container
{
	printf "$gCurrentTime -- Restarting gitlab to use the new certifications. \n" 																																																							>> "$gLogPath"
	cd "$gitlabPath"
	docker-compose restart gitlab > /dev/null 2>&1
	if [[ $? -ne 0 ]];
	then
	printf "$gCurrentTime -- Uh oh. Gitlab has failed to restart! Check your docker logs to find out why.\n" 																																																			>> "$gLogPath"
	printf "$gCurrentTime -- Aborting session.\n" 																																																	>> "$gLogPath"
	_end_session
	exit 1
	fi
	printf "$gCurrentTime -- Everything looks good. You should be up and running in about 5 minutes.\n" 																																																			>> "$gLogPath"
}


#===============================================================================##
## SSL CERTIFICATE DATES -- PRINTS CERT VALID/INVALID DATES TO gLogPath          #
##==============================================================================##
function _show_valid_dates()
{
	validStart=$(/bin/openssl x509 -startdate -noout -in $gCertPath/cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	validEnd=$(/bin/openssl x509 -enddate -noout -in $gCertPath/cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	printf "$gCurrentTime -- You are valid from $validStart through $validEnd. \n" 																																																							>> "$gLogPath"
}


#===============================================================================##
## EXPIRED CERTIFICATES -- PRINTS EXPIRED CERTS MESSAGE TO gLogPath              #
##==============================================================================##
function _expired_certs() {
	printf "$gCurrentTime -- Looks like your certifications have expired! \n" 																																																							>> "$gLogPath"
	printf "$gCurrentTime -- Attempting to update your Let's Encrypt certifications... \n" 																																																							>> "$gLogPath"
}


#===============================================================================##
## VALIDATE CERTS -- ATTEMPTS TO VALIDATE LETS ENCRYPT CERTIFICATIONS            #
##==============================================================================##
function _validate_certs()
{
	local checkCertStatus=$(/bin/openssl x509 -checkend $(( 86400 * gCertExpireDays )) -in $gCertPath/cert.pem)

	if [[ $checkCertStatus == "Certificate will not expire" ]];
	then
	_show_valid_dates
	printf "$gCurrentTime -- No need to renew your certifications! \n" 																																																					>> "$gLogPath"
	else
	_show_valid_dates
	_expired_certs
	_remove_old_certs
	_create_new_certs
	_restart_gitlab_container
	fi
}


#===============================================================================##
## CHECK PATHS -- CHECKS THAT gLetsEncryptPath/gCertPath(cert.pem) EXIST         #
##==============================================================================##
function _check_paths
{
	if [ ! -d "$gLetsEncryptPath" ];
	then
	_abort_session "Unable to locate the Let's Encrypt certifications path. The directory does not exist."
	fi

	if [ ! -d "$gCertPath" ] || [ ! -f "$gCertPath"/cert.pem ];
	then
	_abort_session "Unable to locate the cert.pem file in $gCertPath. The directory and/or file does not exist."
	fi
}


#===============================================================================##
## BEGIN LOG SESSION -- PRINTS TO VALID/INVALID DATES TO gLogPath                #
##==============================================================================##
function _begin_log_session
{
	printf "%s------------------------------------ SESSION STARTED ON $gCurrentDate ----------------------------------\n" 																																						>> "$gLogPath"
	printf "$gCurrentTime -- Attempting to validate your current Let's Encrypt certificates... \n" 																																																							>> "$gLogPath"
}


#===============================================================================##
## CREATE LOG FILE                                                               #
##==============================================================================##
function _create_log_file
{
	if [ ! -f "$gLogPath" ];
	then
	touch "$gLogPath"
	chown -R 1000:1000 "$gLogPath"
	fi
}


#===============================================================================##
## CHECK LOG SIZE -- CHECK IF FILE IS LARGER THAN (gLogMaxSize)MB                #
##==============================================================================##
function _check_log_size
{
	local logSize=$(/bin/stat -c%s "$gLogPath")

	if ((logSize > gLogMaxSize));
	then
	rm $gLogPath
	_create_log_file
	printf "%s--------------------------- LOG FILE WAS TRIMMED ON $gCurrentDate @ $gCurrentTime --------------------------- \n\n" 																																																					>> "$gLogPath"
	fi
}


#===============================================================================##
## MAIN -- RUNS MAIN SCRIPT                                                      #
##==============================================================================##
function main
{
	_create_log_file
	_check_log_size
	_begin_log_session
	_check_paths
	_validate_certs
	_end_session
	exit 0
}


#===============================================================================##
## ENTRY -- CHECK IF FILE IS ROOT                                                #
##==============================================================================##
if [[ `id -u` -ne 0 ]];
	then
		clear
		printf "This script must be run as the ROOT USER! Make sure the script has the correct root permissions.\n" 		>> "$gLogPath"
		exit 1
	else
		main
fi


#===============================================================================##
## EOF                                                                           #
##==============================================================================##
