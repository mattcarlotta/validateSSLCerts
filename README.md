# validateSSLCerts (vSC.sh)

validateSSLCerts (vSC.sh) is an automated bash script that attempts to validate and update a Lets Encrypt SSL certification generated from a Synology NAS (Let's Encrypt Authority X3 certificate). The Let's Encrypt certificate is not only being used by the Synology NAS, but is also being shared with a <a href="https://github.com/sameersbn/docker-gitlab">sameersbn/docker-gitlab</a> container.

## Quick Links

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installation and Usage](#installation-and-usage) - [1. Downloading and Making Script Executable](#1-downloading-and-making-script-executable) - [2. Moving the Script onto your Synology NAS](#2-moving-the-script-onto-your-synology-nas) - [3. SSHing into your Synology NAS](#3-sshing-into-your-synology-nas) - [4. Copying the Script into your Let's Encrypt Certificate Folder](#4-copying-the-script-into-your-lets-encrypt-certificate-folder) - [5. Testing/Running the Script](#5-testingrunning-the-script)
- [Advanced Usage: Custom Flags](#advanced-usage-custom-flags)
- [Automation Through Crontab](#automation-through-crontab) - [Option 1: Implementing a Preconfigured Cron Job](#option-1-implementing-a-preconfigured-cron-job) - [Option 2: Creating a Custom Cron Job](#option-2-creating-a-custom-cron-job)

## Introduction

The idea behind this script is to seamlessly automate the process for updating the shared certificate across services with minimal downtime.

## Requirements

- Have already read the <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6">Let's Encrypt - Synology NAS + sameersbn/docker-gitlab</a> gist
- A Synology device that can generate a Let's Encrypt certificate
- A Synology user with system administrator access (ex: admin)
- A Gitlab certs folder (for example: /volume1/docker/personal/gitlab/gitlab/data/<b>certs</b>)
- Inside the Gitlab certs folder, there needs to be 4 files: `gitlab.key`, `gitlab.crt`, `dhparam.pem`, and a `cert.pem` (see: <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#viewing-synology-generated-certifications">step 9, then step 10</a>)
- RECOMMENDED: For ease of use, I highly recommend adding <a href="https://synocommunity.com/">Synocommunity package sources</a> to your Synology's Package Center, then installing the Nano text editor on your device. Otherwise, you can use the not-so-user-friendly vi text editor.

## Installation and Usage

The following steps need to be done in order...

### 1. Downloading and Making Script Executable

- Download the latest version of vSC.sh to your Desktop by entering the following commands in a terminal window:
  `cd ~/Desktop && curl -O -L https://raw.githubusercontent.com/mattcarlotta/validateSSLCerts/master/vSC.sh`

- You must then change the file permissions to make it executable:
  `chmod +x vSC.sh`

### 2. Moving the Script onto your Synology NAS

- You will then need to SFTP/SCP the vSC.sh script from your Desktop and into your Synology's Gitlab data certs folder (similar to step 10: <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#option-1-scping-file-to-synology-nas">option 1</a> or <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#option-2-sftping-file-to-synology-nas">option 2</a>)

### 3. SSHing into your Synology NAS

- Open a terminal and SSH into your Synology NAS (replace synology_ip_address with your <b>Synology IP</b>) as a <b>system administrator</b>:
  `ssh admin@synology_ip_address -- ex: ssh admin@192.168.1.55`

- Now, type the following command to elevate yourself to a root user:
  `sudo -s`

### 4. Copying the Script into your Let's Encrypt Certificate Folder

- Next, copy the script from the Gitlab certs folder to your Let's Encrypt certifications folder, for example (to find the RANDOM_ALPHANUMERIC_STRING folder, follow <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#viewing-synology-generated-certifications">step 9</a> ):
  `cp /volume1/docker/personal/gitlab/gitlab/data/certs/vSC.sh /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERIC_STRING`

- Remove the script from your Gitlab certs folder:
  `rm /volume1/docker/personal/gitlab/gitlab/data/certs/vSC.sh`

      	<b>Why did we have to move the script into the Gitlab certs folder if we were just going to copy it to another folder, then delete it?</b>
      	- Put simply, the Synology DSM restricts SCP/SFTP to directories owned by you. By transferring from the Gitlab certs folder (owned by you), we can then transfer it to the Let's Encrypt certificate folder (owned by root). Alternatively, we could have changed the ownership of the Let's Encrypt folder from root to you, but that may cause unintended consequences.

### 5. Testing/Running the Script

- Next, `cd` into the Let's Encrypt certifications directory, for example:
  `cd /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERIC_STRING`

- Use this command to run the script:
  `./vSC.sh`
  See [Advanced Usage: Custom Flags](#advanced-usage-custom-flags) for custom configurations.

* To test if the script worked, `cd` back into to your gitlab certs folder and check if a `vSC.log` file exists:
  `cd /volume1/docker/personal/gitlab/gitlab/data/certs ls`

* You should see:
  `cert.cem dhparam.pem gitlab.crt gitlab.key vSC.log`

* You can view the contents of the log by running:
  `cat vSC.log`

* Ideally, you'll want to see something like this:
  `------------------------------------ SESSION STARTED ON 08/12/2018 ---------------------------------- 01:30 AM -- Attempting to validate your current Let's Encrypt certificates. 01:30 AM -- You are valid from Aug 5 15:16:14 2018 GMT through Nov 3 15:16:14 2018 GMT. 01:30 AM -- No need to update yet! Your certificates will not expire within 7 day(s). ------------------------------------------ END OF SESSION -------------------------------------------`

## Advanced Usage: Custom Flags

In order to keep this script as flexible as possible, you can override default options with a flag, for example:

```
./vSC.sh -ls 2000 -gd /srv/docker/gitlab -led /etc/letsencrypt -ac
```

(This can be read as: Run the script, but change: max log size to 2000 bytes, gitlab directory to /srv/docker/gitlab, lets encrypt directory to /etc/letsencrypt, and create a new cron job with these custom options)

You can view all of the custom flag options by running this command:

```
./vSC.sh -h
```

or find them here:

```
SYNOPSIS:
		./vSC.sh [OPTIONS]

OPTIONS:
		 Options below will overwrite their respective defaults (some may have side effects).

		 -ac, -addcron
					adds a new cron job to /etc/crontab (default: runs the script every Monday at 1:30am)
					side effect: any other specified custom flag options will also be appended to the cron job

		 -exp, -expires
					check if certificate expires in specified amount of days; min: 1, max: 30 (default: 30)

		 -gc, -gitcertdir
					Gitlab certificate directory folder (default: /volume1/docker/personal/gitlab/gitlab/data/certs)
					side effect: updates vSC.log directory

		 -gd, -gitlabdir
					Gitlab directory folder (default: /volume1/docker/personal/gitlab)
					side effect: updates Gitlab certificate directory
					side effect: updates vSC.log directory

		 -led, -letsencryptdir
					Let's Encrypt directory folder (default: /usr/syno/etc/certificate/_archive)

		 -lef, -letsencryptfolder
					Let's Encrypt certificate folder (default: automatically calculated via Let's Encrypt directory)

		 -ls, -logsize
					maximum log file size in bytes (default: 10000000)

		 -h, -help
					documentation
```

⚠️ NOTES:

- As noted above, using some flags will update other global variables since some of them rely upon each other.
- The random alphanumeric Let's Encrypt certificate folder will automatically be located by the script (provided that the Let's Encrypt directory is correct). However, if you have multiple certificate folders, then you'll need to use the `-lef` or `-letsencryptfolder` flag followed by the folder name (for example:`-lef 0rOTRe` or `-letsencryptfolder 0rOTRe`).
- If you've already set up a cron job using this script, but decide to add or change any of the custom flag options afterward, then you'll need to add the `-ac` or `-addcron` flag alongside any other specified custom flag options, so that a new cron job will be added to reflect the changes (old cron jobs will automatically be removed).

## Automation Through Crontab

If the script works well when you manually run it, then you can automate it by using crontab.

More information on what a cron is can be found here: <a href="https://help.ubuntu.com/community/CronHowto">Crontab Manual</a>

More information on how to configure a cron job can be found here:
<a href="https://www.cyberciti.biz/faq/how-do-i-add-jobs-to-cron-under-linux-or-unix-oses/">Simplified how to add a job to crontab</a>

### Option 1: Implementing a Preconfigured Cron Job

Simply add the following flag to implement a preconfigured job:

```
./vSC.sh -ac [OPTIONS]
```

Including this flag will add the following job to /etc/crontab:

```
#minute hour    mday    month   wday    who     command
30      1       *       *       1       root    /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERIC_STRING/vSC.sh
```

(The above will read as follows: "Every month, on every Monday within that month, at 1:30 in the morning, run the following command: path/to/script/vSC.sh as a root user"):

### Option 2: Creating a Custom Cron Job

Edit the script:

```
nano /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERIC_STRING/vSC.sh
```

And only update the following script variables:

```
gCronMin=30     # 0-59 minutes
gCronHr=1       # 0-23 hours (0 = 12:00am  ... 23:59 = 11:59pm)
gCronDay=*      # 1-31 days (1st ... 31st)
gCronMon=*      # 1-12 month (1 = January ... 12 = December)
gCronWkday=1    # 0-7 weekday (Sunday = 0/7, Monday = 1, Tuesday = 2, ... Saturday = 6)
```

Please note that asterisks are wildcards, where they'll repeat the command every minute/hour/day/etc unless specified -- with the exception that `gCronWkday` overwrites `gCronDay`.

⚠️ BE ADVISED: Due to the flexible nature of configuring cron jobs, there aren't any sanitation checks on the above script variables. Please follow the notes above and only use numbers within the specified ranges. Special use cases, such as ranged parameters `5-10` or blocked parameters `5, 10` or an asterisk `*`, will work as expected. However, special strings utilizing the `@` short syntax aren't supported in this script.

To save the script changes:

- press `ctrl + o` (this prompts to save the script)
- press `y`, then `enter` (this confirms saving the script)
- press `ctrl + x` (this exits out of the nano editor)

Then run the following command to create/update the cron job:

```
./vSC.sh -ac [OPTIONS]
```
