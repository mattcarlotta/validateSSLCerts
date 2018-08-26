# validateSSLCerts (vSC.sh)

validateSSLCerts (vSC.sh) is an automated bash script that attempts to validate and update a Lets Encrypt SSL certification generated from a Synology NAS (Let's Encrypt Authority X3 certificate). The Let's Encrypt certificate is not only being used by the Synology NAS, but is also being shared with a <a href="https://github.com/sameersbn/docker-gitlab">sameersbn/docker-gitlab</a> container.

## Quick Links

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installation and Usage](#installation-and-usage)
  - [1. Downloading and Making Script Executable](#1-downloading-and-making-script-executable)
  - [2. Moving the Script onto your Synology NAS](#2-moving-the-script-onto-your-synology-nas)
  - [3. SSHing into your Synology NAS](#3-sshing-into-your-synology-nas)
  - [4. Copying the Script into your Let's Encrypt Certificate Folder](#4-copying-the-script-into-your-lets-encrypt-certificate-folder)
  - [5. Testing/Running the Script](#5-testingrunning-the-script)
- [Automation Through Crontab](#automation-through-crontab)
- [Advanced Usage: Custom Flags](#advanced-usage-custom-flags)


## Introduction

The idea behind this script is to seamlessly automate the process for updating the shared certificate across services with minimal downtime.

⚠️ NOTE: This script is currently in the early beta stages!

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
  ```
  cd ~/Desktop && curl -O -L https://raw.githubusercontent.com/mattcarlotta/validateSSLCerts/master/vSC.sh
  ```

- You must then change the file permissions to make it executable:
  ```
  chmod +x vSC.sh
  ```

### 2. Moving the Script onto your Synology NAS

- You will then need to SFTP/SCP the vSC.sh script from your Desktop and into your Synology's Gitlab data certs folder (similar to step 10: <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#option-1-scping-file-to-synology-nas">option 1</a> or <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#option-2-sftping-file-to-synology-nas">option 2</a>)

### 3. SSHing into your Synology NAS

- Open a terminal and SSH into your Synology NAS (replace synology_ip_address with your <b>Synology IP</b>) as a <b>system administrator</b>:
  ```
  ssh admin@SYNOLOGY_IP_ADDRESS -- ex: ssh admin@192.168.1.55
  ```

- Now, type the following command to elevate yourself to a root user:
  ```
  sudo -s
  ```

### 4. Copying the Script into your Let's Encrypt Certificate Folder

- Next, copy the script from the Gitlab certs folder to your Let's Encrypt certifications folder, for example (to find the RANDOM_ALPHANUMERIC_STRING folder, follow <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#viewing-synology-generated-certifications">step 9</a> ):
  ```
  cp /volume1/docker/personal/gitlab/gitlab/data/certs/vSC.sh /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERIC_STRING
  ```

- Remove the vSC.sh from your Gitlab certs folder:
  ```
  rm /volume1/docker/personal/gitlab/gitlab/data/certs/vSC.sh
  ```

  <b>Why did we have to move the script into the Gitlab certs folder if we were just going to copy it to another folder, then delete it?</b>
  - Put simply, the Synology DSM restricts SCP/SFTP to directories owned by you. By transferring from the Gitlab certs folder (owned by you), we can then transfer it to the Let's Encrypt certificate folder (owned by root). Alternatively, we could have changed the ownership of the Let's Encrypt folder from root to you, but that may cause unintended consequences.

### 5. Testing/Running the Script

- Next, `cd` into the Let's Encrypt certifications directory, for example:
  ```
  cd /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERIC_STRING
  ```

- Use this command to run the script:
  ```
  ./vSC.sh
  ```
  See [Advanced Usage: Custom Flags](#advanced-usage-custom-flags) for custom configurations.


- To test if the script worked, `cd` back into to your gitlab certs folder and check if a `vSC.log` file exists:
  ```
  cd /volume1/docker/personal/gitlab/gitlab/data/certs
  ls
  ```

- You should see:
  ```
  cert.cem gitlab.crt gitlab.key vSC.log
  ```

- You can view the contents of the log by running:
  ```
  nano vSC.log
  ```

- Ideally, you'll want to see something like this:
  ```
  ------------------------------------ SESSION STARTED ON 08/12/2018 ----------------------------------
  07:57 PM -- Attempting to validate your current Let's Encrypt certificates.
  07:57 PM -- You are valid from Aug 5 15:16:14 2018 GMT through Nov 3 15:16:14 2018 GMT.
  07:57 PM -- No need to update yet! Your certificates will not expire within 7 day(s).
  ------------------------------------------ END OF SESSION -------------------------------------------
  ```

## Automation Through Crontab

If the script works well when you manually run it, then you can automate it by using crontab.

While still connected via SSH to your Synology NAS as an administrator/root user, run:
```
nano /etc/crontab  
```

You'll see something like this:
```
MAILTO=""
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin:/usr/local/sbin:/usr/local/bin
#minute hour    mday    month   wday    who     command
0       0       1       *       *       root    /usr/syno/bin/syno_disk_health_record
30      4       *       *       1,5     root    /usr/syno/bin/synoschedtask --run id=1
0       0       26      *       *       root    /usr/syno/bin/synoschedtask --run id=2
```

Now you'll want to add your own job, for example (the below will read as follows: "Every month, on every Monday within that month, at 1:30 in the morning, run the following command: path/to/script/vSC.sh as a root user"):
```
#minute hour    mday    month   wday    who     command
30      1       *       *       1       root    /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERICSTRING/vSC.sh
```

More information on how to configure a crontab job can be found here:
<a href="https://www.cyberciti.biz/faq/how-do-i-add-jobs-to-cron-under-linux-or-unix-oses/">Simplified how to add a job to crontab</a>
or
<a href="https://help.ubuntu.com/community/CronHowto">Crontab Manual</a>


## Advanced Usage: Custom Flags

In order to keep this script as flexible as possible, you can override default options with a flag, for example:
```
./vSC.sh -ls 2000 -gd /srv/docker/gitlab -led /etc/letsencrypt
```

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

     -exp, -expires
          check if certificate expires in specified amount of days; min: 1, max: 30 (default: 7)

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
- The random alphanumeric Let's Encrypt certificate folder will be automatically found by the script (as long as the Let's Encrypt directory is correct). However, if you have multiple certificate folders, then you'll need to use the `-lef` or `-letsencryptfolder` flag followed by the folder name (for example:`-lef 0rOTRe`).
