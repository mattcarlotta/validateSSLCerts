#!/bin/bash
#
# Script (validateSSLCerts.sh) to validate Lets Encrypt SSL Certifications for Synology NAS's
#
# Version 0.0.1 alpha - Copyright (c) 2018 by Matt Carlotta
#
# Introduction:
#     - validateSSLCerts is an automated bash script that attempts to validate and
#        update Lets Encrypt SSL Certifications for Synology NAS's running
#        sameersbn/docker-gitlab container
#
#
# Bugs:
#     - Bug reports can be filed at: https://github.com/mattcarlotta/validateSSLCerts/issues
#        Please provide clear steps to reproduce the bug and the output of the
#        script. Thank you!
#

#certRootPath
#/usr/syno/etc/certificate/_archive/

# gitlab container path
gitlabPath="/volume1/docker/personal/gitlab"

# gitlab data certificates path
gCertPath="$HOME"/Documents/gitlabCerts
# gCertPath="$gitlabPath"/gitlab/data/certs

# gitlab data certificates log path
gLogPath="$gCertPath"/validate_cert.log
# gLogPath="$certPath"/check_cert.log

# current date
gCurrentDate=$(date +"%m/%d/%Y")

#current time
gCurrentTime=$(date +"%I:%M %p")

#===============================================================================##
## TODO
##==============================================================================##
# 1. Implement script entry root check
# 2. Give script root ownership
# 3. Test locally
# 4. Move it to root owned directory (like: /etc/validateSSLCerts/validateSSLCerts.sh)
# 5. Set up cron job (sudo crontab -e):
# _________________________________________________________________
# | # Start job every 1 minute                                     |
# | *  *  *  *  *  root  /etc/validateSSLCerts/validateSSLCerts.sh |
# | minute (0-59)                                                  |
# |    hour (0-23)                                                 |
# |       day (1-31)                                               |
# |          month (1-12)                                          |
# |             week day (0-7; 0=Sun)                              |
# |                run as (root)                                   |
# |                      command (path/to/script)                  |
# |________________________________________________________________|
# 6. Init function to create validate_cert.log and give ownership to user (chown -R 1000:1000 /path/to/log)
# 7. Research if Synology NAS autorenews invalidated certs; if not, research how to force renew after X days before
# 8. Implement gitlab docker restart and change gCertPath to remote dir
# 9. Test remotely
# 10. Update README with instructions and include Synology + Gitlab docker gist

#===============================================================================##
## END SESSION #
##==============================================================================##
function _end_session()
{
	printf "%s------------------------------------------ END OF SESSION -------------------------------------------\n\n" 									>> "$gLogPath"
}

#===============================================================================##
## ABORT SESSION #
##==============================================================================##
function _abort_session()
{
	message=$1
	printf "$gCurrentTime -- $message\n" 																																																	>> "$gLogPath"
	printf "$gCurrentTime -- Aborting session.\n" 																																												>> "$gLogPath"
	_end_session
	exit 1
}

#===============================================================================##
## CREATE NEW LETS ENCRYPT CERTIFICATIONS #
##==============================================================================##
function _create_new_certs()
{
	cat privkey.pem > "$gCertPath"/gitlab.key |\
	cat cert.pem fullchain.pem > "$gCertPath"/gitlab.crt |\
	cat cert.pem > "$gCertPath"/cert.pem
	printf "$gCurrentTime -- Added some new certificates to $gCertPath. \n" 																														>> "${gLogPath}"
}

#===============================================================================##
## REMOVE OLD LETS ENCRYPT CERTIFICATIONS #
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
	printf "$gCurrentTime -- Removed the old certificates from $gCertPath. \n" 																														>> "$gLogPath"
}

#===============================================================================##
## RESTART GITLAB CONTAINER
##==============================================================================##
function _restart_gitlab_container
{
	printf "$gCurrentTime -- Restarting gitlab to use the new certifications. \n" 																												>> "$gLogPath"
	# "$gitlabPath"/docker-compose restart gitlab
	if [[ $? -ne 0 ]];
		then
			printf "$gCurrentTime -- Uh oh. Gitlab has failed to restart! Check your docker logs to find out why.\n" 													>> "$gLogPath"
			printf "$gCurrentTime -- Aborting session.\n" 																																										>> "$gLogPath"
			_end_session
			exit 1
	fi
}

#===============================================================================##
## SSL CERTIFICATE DATES #
##==============================================================================##
function _show_valid_dates()
{
	validStart=$(openssl x509 -startdate -noout -in cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	validEnd=$(openssl x509 -enddate -noout -in cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	printf "$gCurrentTime -- You are valid from $validStart through $validEnd. \n" 																												>> "$gLogPath"
}

#===============================================================================##
## EXPIRED CERTIFICATES #
##==============================================================================##
function _expired_certs() {
	printf "$gCurrentTime -- Looks like your certifications have expired! \n" 																														>> "$gLogPath"
	printf "$gCurrentTime -- Attempting to update your Let's Encrypt certifications... \n" 																								>> "$gLogPath"
}


#===============================================================================##
## VALIDATE LETS ENCRYPT CERTIFICATIONS #
##==============================================================================##
function _validate_certs()
{
	if [ ! -f "$gCertPath"/cert.pem ];
		then
			_abort_session "Unable to locate the cert.pem file in $gCertPath."
	fi

	checkCertStatus=$(openssl x509 -noout -checkend 0 -in $gCertPath/cert.pem)
	if [[ $checkCertStatus == "Certificate will not expire" ]];
		then
			_show_valid_dates
			printf "$gCurrentTime -- No need to renew your certifications! \n" 																																>> "$gLogPath"
	else
		_show_valid_dates
		_expired_certs
		_remove_old_certs
		_create_new_certs
		_restart_gitlab_container
	fi
}

function _greet
{
	printf "%s------------------------------------ SESSION STARTED ON $gCurrentDate ----------------------------------\n" 								>> "$gLogPath"
	printf "$gCurrentTime -- Attempting to validate your current Let's Encrypt certificates... \n" 																				>> "$gLogPath"
}

function main
{
	_greet
	_validate_certs
	_end_session
	exit 0
}

main

#check if file is ROOT, if not, exit script
# if [[ `id -u` -ne 0 ]];
#   then
#     clear
#     printf "This script must be run as the ROOT USER! Make sure the script has the correct root permissions.\n"
#     exit 1
#   else
#     main
#     exit 0
# fi
