#!/bin/bash
#
# Script (validateSSLCerts.sh) to validate Lets Encrypt SSL Certifications for Synology NAS's
#
# Version 0.0.3b - Copyright (c) 2018 by Matt Carlotta
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
# 1. Automate a search for gLetsEncryptDir's alphanumeric folder
# 2. Update README with instructions
# 3. Research if Synology NAS autorenews invalidated certs; if not, research how to force renew after X days before


#===============================================================================##
## GLOBAL VARIABLES                                                              #
##==============================================================================##
# current script version
version="0.0.3b"

# bold text
bold=$(tput bold)

# underline text
underline=$(tput smul)
stopunderline=$(tput rmul)

# normal text
normal=$(tput sgr0)

# path used by crontab for running localized commands
# gCommandPath="/usr/bin" # local
gCommandPath="/bin" # remote

# Gitlab container path
gGitlabDir="/volume1/docker/personal/gitlab"

# Gitlab data certificates path
gCertDir="$gGitlabDir"/gitlab/data/certs # remote

# Synology certficate directory
gSynCertDir="/usr/syno/etc/certificate/_archive" # remote

# Lets Encrypt certifications directory
gLetsEncryptDir="$gSynCertDir"/0rOTRe # remote

# gitlab data certificates log path
gLogPath="$gCertDir"/vCS.log

# amount of days to check cert against (will expire in X days?)
gCertExpireDays=7 # 7 days

# max log file size in bytes
gLogMaxSize=10000000 # (10mb)

# current date
gCurrentDate=$(/bin/date +"%m/%d/%Y")

# current time
gCurrentTime=$(/bin/date +"%I:%M %p")

# custom flag messages that need to be printed to the log
gMessageStore=()


#===============================================================================##
## CHECK LOG SIZE -- IF FILE IS LARGER THAN gLogMaxSize Bytes, TRIM 20 LINES     #
##==============================================================================##
function _check_log_size()
{
	local logSize=$($gCommandPath/stat -c%s "$gLogPath")

	if ((logSize > gLogMaxSize));
		then
			sed -i '1,18d' $gLogPath
	fi
}

#===============================================================================##
## END SESSION                                                                   #
##==============================================================================##
function _end_session()
{
	printf "%s------------------------------------------ END OF SESSION -------------------------------------------\n\n"                  >> "$gLogPath"
}


#===============================================================================##
## BEGIN SESSION -- PRINTS A SESSION TO gLogPath                                 #
##==============================================================================##
function _begin_session()
{
	printf "%s------------------------------------ SESSION STARTED ON $gCurrentDate ----------------------------------\n"                 >> "$gLogPath"
}


#===============================================================================##
## PRINT MESSAGE -- PRINTS ANY MESSAGES TO vCS.log                               #
##==============================================================================##
function _printMessage()
{
	local message=$1
	printf "$gCurrentTime -- $message \n"                                                                                                 >> "$gLogPath"
}


#===============================================================================##
## ABORT SESSION  -- PRINTS MESSAGES TO gLogPath AND EXITS SCRIPT                #
##==============================================================================##
function _abort_session()
{
	local error=$1
	_create_log_file
	_begin_session
	_printMessage "$error"
	_printMessage "Aborting session."
	_end_session
	_check_log_size
	exit 1
}


#===============================================================================##
## CREATE NEW CERTS -- CREATES NEW LETS ENCRYPT CERTIFICATIONS FOR GITLAB        #
##==============================================================================##
function _create_new_certs()
{
	cat "$gLetsEncryptDir"/privkey.pem > "$gCertDir"/gitlab.key |\
	cat "$gLetsEncryptDir"/cert.pem "$gLetsEncryptDir"/fullchain.pem > "$gCertDir"/gitlab.crt |\
	cat "$gLetsEncryptDir"/cert.pem > "$gCertDir"/cert.pem

	chown 1000:1000 "$gCertDir"/gitlab.key "$gCertDir"/gitlab.crt "$gCertDir"/cert.pem

	_printMessage "Added some new certificates to $gCertDir."
}


#===============================================================================##
## REMOVE OLD CERTS -- REMOVES LETS ENCRYPT CERTS FROM GITLAB FOLDER             #
##==============================================================================##
function _remove_old_certs()
{
	if [ ! -f "$gCertDir"/cert.pem ] || [ ! -f "$gCertDir"/gitlab.key ] || [ ! -f "$gCertDir"/gitlab.key ];
		then
			_abort_session "Unable to locate your current certifications in $gCertDir."
	fi

	rm "$gCertDir"/cert.pem "$gCertDir"/gitlab.key "$gCertDir"/gitlab.crt > /dev/null 2>&1
	if [[ $? -ne 0 ]];
		then
			_abort_session "Unable to remove your current certifications."
	fi

	_printMessage "Removed the old certificates from $gCertDir."
}


#===============================================================================##
## RESTART GITLAB CONTAINER -- RESTARTS GITLAB CONTAINER TO USE NEW CERTS        #
##==============================================================================##
function _restart_gitlab_container()
{
	_printMessage "Restarting gitlab to use the new certifications."

	cd "$gGitlabDir"
	docker-compose restart gitlab > /dev/null 2>&1
	if [[ $? -ne 0 ]];
		then
			_abort_session "Uh oh. Gitlab has failed to restart! Check your docker logs to find out why."
	fi

	_printMessage "Everything looks good. You should be up and running in about 5 minutes."
}


#===============================================================================##
## SSL CERTIFICATE DATES -- PRINTS CERT VALID/INVALID DATES TO gLogPath          #
##==============================================================================##
function _show_valid_dates()
{
	validStart=$($gCommandPath/openssl x509 -startdate -noout -in $gCertDir/cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	validEnd=$($gCommandPath/openssl x509 -enddate -noout -in $gCertDir/cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	_printMessage "You are valid from $validStart through $validEnd."
}


#===============================================================================##
## EXPIRED CERTIFICATES -- PRINTS EXPIRED CERTS MESSAGE TO gLogPath              #
##==============================================================================##
function _expired_certs()
{
	_printMessage "Looks like your certifications have expired!"
	_printMessage "Attempting to update your Let's Encrypt certifications."
}


#===============================================================================##
## VALIDATE CERTS -- ATTEMPTS TO VALIDATE LETS ENCRYPT CERTIFICATIONS            #
##==============================================================================##
function _validate_certs()
{
	_printMessage "Attempting to validate your current Let's Encrypt certificates."

	local checkCertStatus=$($gCommandPath/openssl x509 -checkend $(( 86400 * gCertExpireDays )) -in $gCertDir/cert.pem)

	if [[ $checkCertStatus == "Certificate will not expire" ]];
		then
			_show_valid_dates
			_printMessage "No need to renew your certifications!"
	else
		_show_valid_dates
		_expired_certs
		_remove_old_certs
		_create_new_certs
		_restart_gitlab_container
	fi
}


#===============================================================================##
## CHECK PATHS -- CHECKS THAT gLetsEncryptDir/gCertDir(cert.pem) EXIST           #
##==============================================================================##
function _check_paths()
{
	if [ ! -d "$gLetsEncryptDir" ];
		then
		_abort_session "Unable to locate the Let's Encrypt certifications path. The directory does not exist."
	fi

	if [ ! -d "$gCertDir" ] || [ ! -f "$gCertDir"/cert.pem ];
		then
		_abort_session "Unable to locate the cert.pem file in $gCertDir. The directory and/or file does not exist."
	fi
}

#===============================================================================##
## SHOW HELP -- PRINTS HELP OPTIONS TO TERMINAL                                  #
##==============================================================================##
function _show_help()
{
	printf "\n${bold}NAME:${normal}\n"
	printf "      ${bold}validateSSLCerts v$version${normal} - validate and update a Lets Encrypt SSL certification \n"
	printf "\n${bold}SYNOPSIS:${normal}\n"
	printf "      ${bold}./vCS.sh${normal} [${underline}OPTIONS${stopunderline}]\n"
	printf "\n${bold}OPTIONS:${normal}\n"
	printf "     Options below will overwrite their respective defaults (some may have side effects).\n\n"
	printf "     ${bold}-exp${normal}, ${bold}-expires${normal}\n"
	printf "          check if certificate expires in specified amount of days (default: $gCertExpireDays)\n\n"
	printf "     ${bold}-gc${normal}, ${bold}-gitcertdir${normal}\n"
	printf "          Gitlab certificate directory folder (default: $gCertDir)\n"
	printf "          side effect: updates vCS.log directory\n\n"
	printf "     ${bold}-gd${normal}, ${bold}-gitlabdir${normal}\n"
	printf "          Gitlab directory folder (default: $gGitlabDir)\n"
	printf "          side effect: updates Gitlab certificate directory\n"
	printf "          side effect: updates vCS.log directory\n\n"
	printf "     ${bold}-led${normal}, ${bold}-letsencryptdir${normal}\n"
	printf "          Let's Encrypt directory folder (default: $gLetsEncryptDir)\n\n"
	printf "     ${bold}-ls${normal}, ${bold}-logsize${normal}\n"
	printf "          maximum vCS.log file size in bytes (default: $gLogMaxSize)\n\n"
	printf "     ${bold}-h${normal}, ${bold}-help${normal}\n"
	printf "          help documentation\n\n"
	exit 0
}


#===============================================================================##
## PRINT ERROR -- PRINTS FOUND FLAG ERRORS                                       #
##==============================================================================##
function _printError()
{
	case "$1" in
		2) _abort_session "The supplied Gitlab certification path: $2 does not exist."
				;;
		3) _abort_session "The supplied Gitlab directory: $2 does not exist."
				;;
		4) _abort_session "The supplied Let's Encrypt directory: $2 does not exist."
				;;
		5) _abort_session "The log file size must be larger than 1kb and less than 100mb."
				;;
		*) _abort_session "The expires in must be greater than 0 and less than 90 days."
				;;
	esac
}

#===============================================================================##
## INVALID ARGUMENT -- PRINTS ANY INVALID CUSTOM FLAGS                           #
##==============================================================================##
function _invalidArgument()
{
	_abort_session "Invalid argument detected: ${1} (check vCS.sh -h)"
}

#===============================================================================##
## MESSAGE STORE -- PRINTS ANY CUSTOM FLAGS MESSAGES TO vSC.log                  #
##==============================================================================##
function _message_store()
{
	if [[ ${gMessageStore[@]} ]];
		then
			for messages in "${gMessageStore[@]}";
				do
					_printMessage "$messages"
			done
	fi
}


#===============================================================================##
## CUSTOM FLAGS -- OVERRIDES GLOBAL VARIABLES                                    #
##==============================================================================##
function _custom_flags()
{
	if [ $# -gt 0 ];
		then
			local argument=$(echo "$1" | tr '[:upper:]' '[:lower:]')

			if [[ $# -eq 1 && "$argument" == "-h" || "$argument" == "-help"  ]];
			 then
				_show_help
			fi

			while [ "$1" ];do
				local flag=$(echo "$1" | tr '[:upper:]' '[:lower:]')
				if [[ "${flag}" =~ ^[-abcdefghiklmnoprsutvwx]+$ ]];
					then
						case "${flag}" in

							-exp|-expires) shift
								if [[ "$1" =~ ^[0-9]+$ ]];
									then
										if [ $1 -lt 0 ] || [ $1 -ge 90 ];
											then
												_printError 1 $1
											else
												gCertExpireDays=$1
												gMessageStore+=("Overriden the certification expires in to: ${gCertExpireDays} days")
										fi
									else
										_invalidArgument "-e|-expires $1"
								fi
								;;

							-gc|-gitcertdir) shift
								if [[ "$1" =~ ^(.+)/([^/]+)$ ]];
									then
										if [ ! -d "$1" ];
											then
												_printError 2 $1
											else
												gCertDir=$1
												gLogPath="$gCertDir"/vCS.log
												gMessageStore+=("Overriden the Gitlab certification path to: ${gCertDir}")
												gMessageStore+=("Overriden the vCS.log path: ${gLogPath}")
										fi
									else
										_invalidArgument "-gc|-gitcertdir $1"
								fi
								;;

							-gd|-gitlabdir) shift
								if [[ "$1" =~ ^(.+)/([^/]+)$ ]];
									then
										if [ ! -d "$1" ];
											then
												_printError 3 $1
											else
												gGitlabDir=$1
												gCertDir="$gGitlabDir"/gitlab/data/certs
												gLogPath="$gCertDir"/vCS.log
												gMessageStore+=("Overriden the Gitlab directory path to: ${gGitlabDir}")
												gMessageStore+=("Overriden the Gitlab certification path to: ${gCertDir}")
												gMessageStore+=("Overriden the vCS.log path: ${gLogPath}")
										fi
									else
										_invalidArgument "-gd|-gitlabdir $1"
								fi
								;;

							-led|-letsencryptdir) shift
								if [[ "$1" =~ ^(.+)/([^/]+)$ ]];
									then
										if [ ! -d "$1" ];
											then
												_printError 4 $1
											else
												gLetsEncryptDir=$1
												gMessageStore+=("Overriden the Let's Encrypt directory path to: ${gLetsEncryptDir}")
										fi
									else
										_invalidArgument "-led|-letsencryptdir $1"
								fi
								;;

							-ls|-logsize) shift
								if [[ "$1" =~ ^[0-9]+$ ]];
									then
										if [ $1 -lt 2000 ] || [ $1 -gt 100000000 ];
											then
													_printError 5 $1
											else
												gLogMaxSize=$1
												gMessageStore+=("Overriden the max log file size to: ${gLogMaxSize}")
										fi
									else
										_invalidArgument "-ls|-logsize $1"
								fi
								;;

							*) _invalidArgument "$1"
								;;
							esac
						else
							_invalidArgument "$1"
				fi
				shift;
			done;
	fi
}


#===============================================================================##
## CREATE LOG FILE                                                               #
##==============================================================================##
function _create_log_file()
{
	if [ ! -f "$gLogPath" ];
		then
			touch "$gLogPath"
			chown -R 1000:1000 "$gLogPath"
	fi
}


#===============================================================================##
## MAIN -- RUNS MAIN SCRIPT                                                      #
##==============================================================================##
function main()
{
	_custom_flags "$@"
	_create_log_file
	_begin_session
	_message_store
	_check_paths
	_validate_certs
	_end_session
	_check_log_size
	exit 0
}


#===============================================================================##
## ENTRY -- CHECK IF USER IS ROOT                                                #
##==============================================================================##
if [[ `id -u` -ne 0 ]];
	then
		clear
		_create_log_file
		_begin_session
		_abort_session "This script must be run as the ROOT USER! Make sure the script has the correct root permissions.\n"
	else
		main "$@"
fi


#===============================================================================##
## EOF                                                                           #
##==============================================================================##
