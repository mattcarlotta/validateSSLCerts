#!/bin/bash
#
# Script to validate Lets Encrypt SSL Certifications for Synology NAS's
#
# Version 0.0.8b - Copyright (c) 2018 by Matt Carlotta
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
## GLOBAL VARIABLES                                                              #
##==============================================================================##
# current script version
version="0.0.8b"

# path used by crontab for running localized commands
gCommandPath="/bin"

# crontab defaults
gCronDir="/etc/crontab" # crontab directory
gCronMin=30 # 0-59 minutes
gCronHr=1 # 0-23 hours (0 = 12:00am  ... 23:59 = 11:59pm)
gCronDay="*" # 1-31 days (1st ... 31st)
gCronMon="*" # 1-12 month (1 = January ... 12 = December)
gCronWkday=1 # 0-7 weekday (Sunday = 0/7, Monday = 1, Tuesday = 2, ... Saturday = 6)
gCronUpdate=false # determine whether to update cron job

# Gitlab container path
gGitlabDir="/volume1/docker/personal/gitlab"

# Gitlab data certificates path
gGitlabCertDir="$gGitlabDir"/gitlab/data/certs

# Let's Encrypt certficate directory
gLECertDir="/usr/syno/etc/certificate/_archive"

# Lets Encrypt certifications folder
gLEFolder="DEFAULT"

# Lets Encrypt certificate renewal
gRenewCertCommand=$(/usr/syno/sbin/syno-letsencrypt renew-all)

# Gitlab data certificates log path
gLogPath="$gGitlabCertDir"/vSC.log

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

# determine whether a log session has started
gSession=false


#===============================================================================##
## END SESSION                                                                   #
##==============================================================================##
function _end_session()
{
	printf "%s------------------------------------------ END OF SESSION -------------------------------------------\n\n"                      >> "$gLogPath"
}


#===============================================================================##
## BEGIN SESSION -- PRINTS A SESSION TO gLogPath                                 #
##==============================================================================##
function _begin_session()
{
	printf "%s------------------------------------ SESSION STARTED ON $gCurrentDate ----------------------------------\n"                     >> "$gLogPath"
}


#===============================================================================##
## SESSION CHECK -- CHECKS IF SESSION ACTIVE                                     #
##==============================================================================##
function _session_active()
{
	if [ $gSession = false ];
		then
			gSession=true
			_begin_session
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
## PRINT MESSAGE -- PRINTS ANY MESSAGES TO vSC.log                               #
##==============================================================================##
function _print_message()
{
	local message=$1
	printf "$gCurrentTime -- $message \n"                                                                                                     >> "$gLogPath"
}

#===============================================================================##
## SET CRONJOB -- SETS UP AN AUTOMATED CRON JOB FOR RUNNING THE SCRIPT           #
##==============================================================================##
function _set_cron_job()
{
	if [ "$gCronUpdate" = true ];
		then
			local cronjob=$(grep "vSC.sh" $gCronDir)
			local args=$(echo $@ | sed -e 's/-addcron//g; s/-ac//g')

			if [ ! -z "$cronjob" ];
				then
					sed -i "/.vSC.sh/d" $gCronDir
					_print_message "Removed a previous cron job from your crontab."
			fi

			printf "$gCronMin      $gCronHr       $gCronDay       $gCronMon       $gCronWkday       root    $gLECertDir/$gLEFolder/vSC.sh $args"  >> "$gCronDir"
			_print_message "Added a new cron job to your crontab."
	fi
}


#===============================================================================##
## CHECK LOG SIZE -- IF FILE IS LARGER THAN gLogMaxSize Bytes, TRIM LINES        #
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
## ABORT SESSION  -- PRINTS MESSAGES TO gLogPath AND EXITS SCRIPT                #
##==============================================================================##
function _abort_session()
{
	local error=$1
	_create_log_file
	_session_active
	_print_message "$error"
	_print_message "Aborting session."
	_end_session
	_check_log_size
	exit 1
}


#===============================================================================##
## RESTART GITLAB CONTAINER -- RESTARTS GITLAB CONTAINER TO USE NEW CERTS        #
##==============================================================================##
function _restart_gitlab_container()
{
	_print_message "Restarting gitlab to use the new certifications."

	cd "$gGitlabDir"
	docker-compose restart gitlab > /dev/null 2>&1
	if [[ $? -ne 0 ]];
		then
			_abort_session "Uh oh. Gitlab has failed to restart! Check your docker logs to find out why."
	fi

	_print_message "Everything looks good. You should be up and running in about 5 minutes."
}


#===============================================================================##
## CREATE NEW CERTS -- CREATES NEW LETS ENCRYPTgCronUpdate CERTIFICATIONS FOR GITLAB        #
##==============================================================================##
function _create_new_certs()
{
	local LEfolder="$gLECertDir"/"$gLEFolder"

	cat "$LEfolder"/privkey.pem > "$gGitlabCertDir"/gitlab.key |\
	cat "$LEfolder"/cert.pem "$LEfolder"/fullchain.pem > "$gGitlabCertDir"/gitlab.crt |\
	cat "$LEfolder"/cert.pem > "$gGitlabCertDir"/cert.pem

	chown 1000:1000 "$gGitlabCertDir"/gitlab.key "$gGitlabCertDir"/gitlab.crt "$gGitlabCertDir"/cert.pem

	_print_message "Added some new certificates to $gGitlabCertDir."
}


#===============================================================================##
## REMOVE OLD CERTS -- REMOVES LETS ENCRYPT CERTS FROM GITLAB FOLDER             #
##==============================================================================##
function _remove_old_certs()
{
	if [[ ! -f "$gGitlabCertDir"/cert.pem || ! -f "$gGitlabCertDir"/gitlab.key || ! -f "$gGitlabCertDir"/gitlab.crt ]];
		then
			_abort_session "Unable to locate your current certifications in $gGitlabCertDir."
	fi

	rm "$gGitlabCertDir"/cert.pem "$gGitlabCertDir"/gitlab.key "$gGitlabCertDir"/gitlab.crt > /dev/null 2>&1
	if [[ $? -ne 0 ]];
		then
			_abort_session "Unable to remove your current certifications."
	fi

	_print_message "Removed the old certificates from $gGitlabCertDir."
}


#===============================================================================##
## COMPARE CERTS  --  CHECKS IF LE CERT HAS BEEN UPDATED                         #
##==============================================================================##
function _compare_certs()
{
	local LECert=$(sed '1d; $d' $gLECertDir/$gLEFolder/cert.pem)
	local GitCert=$(sed '1d; $d' $gGitlabCertDir/cert.pem)

	if [ "$LECert" =  "$GitCert" ];
		then
			_print_message "Uh oh, it looks like your Let's Encrypt certificates failed to be renewed."
			_abort_session "You will need to manually renew them before attempting to run this script again."
	fi
}


#===============================================================================##
## UPDATE CERTS  --  ATTEMPTS TO FORCE RENEW LETS ENCRYPT CERTIFICATES           #
##==============================================================================##
function _update_certs()
{
	_print_message "Attempting to renew your certifications."
	# may not be neccessary as the NAS may autorenew invalidated certs
	$gRenewCertCommand > /dev/null 2>&1
	if [[ $? -ne 0 ]];
		then
			_abort_session "Unable to renew your Let's Encrypt certificates."
	fi
}


#===============================================================================##
## EXPIRED CERTIFICATES -- PRINTS EXPIRED CERTS MESSAGE TO gLogPath              #
##==============================================================================##
function _expired_certs()
{
	_print_message "Looks like your certifications will expire within $gCertExpireDays day(s)."
}


#===============================================================================##
## SSL CERTIFICATE DATES -- PRINTS CERT VALID/INVALID DATES TO gLogPath          #
##==============================================================================##
function _show_valid_dates()
{
	local validStart=$($gCommandPath/openssl x509 -startdate -noout -in $gGitlabCertDir/cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	local validEnd=$($gCommandPath/openssl x509 -enddate -noout -in $gGitlabCertDir/cert.pem | cut -d = -f 2 | sed 's/ \+/ /g')
	_print_message "You are valid from $validStart through $validEnd."
}


#===============================================================================##
## VALIDATE CERTS -- ATTEMPTS TO VALIDATE LETS ENCRYPT CERTIFICATIONS            #
##==============================================================================##
function _validate_certs()
{
	_print_message "Attempting to validate your current Let's Encrypt certificates."

	local checkCertStatus=$($gCommandPath/openssl x509 -checkend $(( 86400 * gCertExpireDays )) -in $gGitlabCertDir/cert.pem)

	if [[ $checkCertStatus == "Certificate will not expire" ]];
		then
			_show_valid_dates
			_print_message "No need to update yet! Your certificates will not expire within $gCertExpireDays day(s)."
	else
		_show_valid_dates
		_expired_certs
		_update_certs
		_compare_certs
		_remove_old_certs
		_create_new_certs
		_restart_gitlab_container
	fi
}


#===============================================================================##
## CHECK PATHS -- gLECertDir/gLEFolder & /gGitlabCertDir/cert.pem EXIST          #
##==============================================================================##
function _check_paths()
{
	if [[ ! -d "$gLECertDir" || ! -d "$gLECertDir"/"$gLEFolder" ]];
		then
		_abort_session "Unable to locate the Let's Encrypt directory or folder path."
	fi

	if [[ ! -d "$gGitlabCertDir" || ! -f "$gGitlabCertDir"/cert.pem ]];
		then
		_abort_session "Unable to locate the cert.pem file in $gGitlabCertDir."
	fi
}


#===============================================================================##
## SHOW HELP -- PRINTS HELP OPTIONS TO TERMINAL                                  #
##==============================================================================##
function _show_help()
{
	printf "\nNAME:\n"
	printf "      validateSSLCerts v$version - validate and update a Lets Encrypt SSL certification \n"
	printf "\nSYNOPSIS:\n"
	printf "      ./vSC.sh [OPTIONS]\n"
	printf "\nOPTIONS:\n"
	printf "     Options below will overwrite their respective defaults (some may have side effects).\n\n"
	printf "     -ac, -addcron\n"
	printf "          adds a new cron job to /etc/crontab (default: runs the script every Monday at 1:30am)\n"
	printf "          side effect: any other specified custom flag options will also be appended to the cron job\n\n"
	printf "     -exp, -expires\n"
	printf "          check if certificate expires in specified amount of days; min: 1, max: 30 (default: $gCertExpireDays)\n\n"
	printf "     -gc, -gitcertdir\n"
	printf "          Gitlab certificate directory folder (default: $gGitlabCertDir)\n"
	printf "          side effect: updates vSC.log directory\n\n"
	printf "     -gd, -gitlabdir\n"
	printf "          Gitlab directory folder (default: $gGitlabDir)\n"
	printf "          side effect: updates Gitlab certificate directory\n"
	printf "          side effect: updates vSC.log directory\n\n"
	printf "     -led, -letsencryptdir\n"
	printf "          Let's Encrypt directory folder (default: $gLECertDir)\n\n"
	printf "     -lef, -letsencryptfolder\n"
	printf "          Let's Encrypt certificate folder (default: automatically calculated via Let's Encrypt directory)\n\n"
	printf "     -ls, -logsize\n"
	printf "          maximum log file size in bytes (default: $gLogMaxSize)\n\n"
	printf "     -h, -help\n"
	printf "          documentation\n\n"
	exit 0
}


#===============================================================================##
## PRINT ERROR -- PRINTS FOUND FLAG ERRORS                                       #
##==============================================================================##
function _print_error()
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
		*) _abort_session "The expires in must be greater than 0 and less than 30 days."
		;;
	esac
}


#===============================================================================##
## INVALID ARGUMENT -- PRINTS ANY INVALID CUSTOM FLAGS                           #
##==============================================================================##
function _invalid_argument()
{
	_abort_session "Invalid argument detected: ${1} (check vSC.sh -h)"
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
					_print_message "$messages"
			done
	fi
}


#===============================================================================##
## FIND LE CERT FOLDER -- LOCATES LETS ENCRYPT FOLDER IF NOT SUPPLIED            #
##==============================================================================##
function _find_le_cert_folder()
{
	if [ $gLEFolder = "DEFAULT" ];
		then
			cd "$gLECertDir"
			local folder=$(/bin/ls | sed -e 's/\(INFO\)*$//g; s/\(DEFAULT\)*$//g;')

			if [ $folder ];
				then
					gLEFolder="$folder"
				else
					abort_session "Unable to locate a Let's Encrypt folder"
			fi
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

			while [ "$1" ];
				do
					local flag=$(echo "$1" | tr '[:upper:]' '[:lower:]')

					if [[ "${flag}" =~ ^[-abcdefghiklmnoprsutvwx]+$ ]];
						then
							case "${flag}" in

								-ac|-addcron)
										gCronUpdate=true
										gMessageStore+=("Overriden the cron update to true.")
								;;

								-exp|-expires) shift
									if [[ "$1" =~ ^[0-9]+$ ]];
										then
											if [[ $1 -lt 1  ||  $1 -gt 30 ]];
												then
													_print_error 1 $1
												else
													gCertExpireDays=$1
													gMessageStore+=("Overriden the certification expires in to: ${gCertExpireDays} day(s).")
											fi
										else
											_invalid_argument "-e|-expires $1"
									fi
								;;

								-gc|-gitcertdir) shift
									if [[ "$1" =~ ^(.+)/([^/]+)$ ]];
										then
											if [ ! -d "$1" ];
												then
													_print_error 2 $1
												else
													gGitlabCertDir=$1
													gLogPath="$gGitlabCertDir"/vSC.log
													gMessageStore+=("Overriden the Gitlab certification path to: ${gGitlabCertDir}.")
													gMessageStore+=("Overriden the vSC.log path: ${gLogPath}.")
											fi
										else
											_invalid_argument "-gc|-gitcertdir $1"
									fi
								;;

								-gd|-gitlabdir) shift
									if [[ "$1" =~ ^(.+)/([^/]+)$ ]];
										then
											if [ ! -d "$1" ];
												then
													_print_error 3 $1
												else
													gGitlabDir=$1
													gGitlabCertDir="$gGitlabDir"
													gLogPath="$gGitlabCertDir"/vSC.log
													gMessageStore+=("Overriden the Gitlab directory path to: ${gGitlabDir}.")
													gMessageStore+=("Overriden the Gitlab certification path to: ${gGitlabCertDir}.")
													gMessageStore+=("Overriden the vSC.log path: ${gLogPath}.")
											fi
										else
											_invalid_argument "-gd|-gitlabdir $1"
									fi
								;;

								-led|-letsencryptdir) shift
									if [[ "$1" =~ ^(.+)/([^/]+)$ ]];
										then
											if [ ! -d "$1" ];
												then
													_print_error 4 $1
												else
													gLECertDir=$1
													gMessageStore+=("Overriden the Let's Encrypt directory path to: ${gLECertDir}.")
											fi
										else
											_invalid_argument "-led|-letsencryptdir $1"
									fi
								;;

								-lef|-letsencryptfolder) shift
									if [[ "$1" =~ ^[A-Za-z0-9_.]+$ ]];
										then
											gLEFolder=$1
											gMessageStore+=("Overriden the Let's Encrypt folder name to: ${gLEFolder}.")
										else
											_invalid_argument "-lef|-letsencryptfolder $1"
									fi
								;;

								-ls|-logsize) shift
									if [[ "$1" =~ ^[0-9]+$ ]];
										then
											if [[ $1 -lt 2000 || $1 -gt 100000000 ]];
												then
														_print_error 5 $1
												else
													gLogMaxSize=$1
													gMessageStore+=("Overriden the max log file size to: ${gLogMaxSize} bytes.")
											fi
										else
											_invalid_argument "-ls|-logsize $1"
									fi
								;;

								*) _invalid_argument "$1"
								;;
						esac
					else
						_invalid_argument "$1"
				fi
				shift;
			done;
	fi
}


#===============================================================================##
## MAIN -- RUNS MAIN SCRIPT                                                      #
##==============================================================================##
function main()
{
	_custom_flags "$@"
	_create_log_file
	_session_active
	_find_le_cert_folder
	_message_store
	_check_paths
	_validate_certs
	_set_cron_job "$@"
	_end_session
	_check_log_size
	exit 0
}


#===============================================================================##
## ENTRY -- CHECK IF USER IS ROOT                                                #
##==============================================================================##
if [[ `id -u` -ne 0 ]];
	then
		_abort_session "This script must be run as the ROOT user! Make sure the script has the correct ROOT permissions.\n"
	else
		main "$@"
fi


#===============================================================================##
## EOF                                                                           #
##==============================================================================##
