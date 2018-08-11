# validateSSLCerts (vSC.sh)

## Quick Links

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installation and Usage](#installation-and-usage)
  - [1. Downloading and Making Script Executable](#downloading-and-making-script-executable)
  - [2. Moving the Script onto your Synology NAS](#moving-the-script-onto-your-synology-nas)
  - [3. SSHing into your Synology NAS](#sshing-into-your-synology-nas)
  - [4. Copying the Script into your Let's Encrypt Certificate Folder](#copying-the-script-into-your-lets-encrypt-certificate-folder)
  - [5. Testing/Running the Script](#testingrunning-the-script)
- [Advanced Usage - Automation Through Crontab](#advanced-usage---automation-through-crontab)
- [Using Custom Flags](#using-custom-flags)


## Introduction

validateSSLCerts (vSC.sh) is an automated bash script that attempts to validate and update a Lets Encrypt SSL certification generated from a Synology NAS (Let's Encrypt Authority X3 certificate). The certificate is not only being used by the Synology NAS, but is also being shared with a <a href="https://github.com/sameersbn/docker-gitlab">sameersbn/docker-gitlab</a> container. The idea is to seamlessly automate the process for updating the shared certificate across services with minimal downtime.

Please read my gist about Let's Encrypt with a Synology NAS running a Gitlab container before using this script: <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6">Let's Encrypt - Synology NAS + sameersbn/docker-gitlab</a>

⚠️ NOTE: This script is currently in the early beta stages!

## Requirements

- A Synology device that can generate a Let's Encrypt certificate
- A Synology user with system administrator access (ex: admin)
- A Gitlab certs folder (for example: /volume1/docker/personal/gitlab/gitlab/data/<b>certs</b>)
- Inside the Gitlab certs folder, there needs to be 4 files: `gitlab.key`, `gitlab.crt`, `dhparam.pem`, and a `cert.pem` (the cert.pem needs to be copied over from the Let's Encrypt certificate folder)
- RECOMMENDED: For ease of use, I highly recommend adding <a href="https://synocommunity.com/">Synocommunity package sources</a> to your Synology's Package Center, then installing the Nano text editor on your device. Otherwise, you can use the not-so-user-friendly vi text editor.


## Installation and Usage

## Downloading and Making Script Executable

- Download the latest version of vSC.sh to your Desktop by entering the following commands in a terminal window:
  ```
  cd ~/Desktop && curl -O -L https://raw.githubusercontent.com/mattcarlotta/validateSSLCerts/master/vSC.sh
  ```

- You must then change the file permissions to make it executable:
  ```
  chmod +x vSC.sh
  ```

## Moving the Script onto your Synology NAS

- You will then need to SFTP/SCP the vSC.sh script from your Desktop and into your Synology's Gitlab data certs folder (similiar to step 10: <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#option-1-scping-file-to-synology-nas">option 1</a> or <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#option-2-sftping-file-to-synology-nas">option 2</a>)

## SSHing into your Synology NAS

- Open a terminal and SSH into your Synology NAS (replace synology_ip_address with your <b>Synology IP</b>) as a <b>system administrator</b>:
  ```
  ssh admin@SYNOLOGY_IP_ADDRESS -- ex: ssh admin@192.168.1.55
  ```

- Now, type the following command to elevate yourself to a root user:
  ```
  sudo -s
  ```

## Copying the Script into your Let's Encrypt Certificate Folder

- Next, copy the script from the Gitlab certs folder to your Let's Encrypt certifications folder, for example (to find the RANDOM_ALPHANUMERICSTRING folder, follow <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6#viewing-synology-generated-certifications">step 9</a> ):
  ```
  cp /volume1/docker/personal/gitlab/gitlab/data/certs/vSC.sh /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERICSTRING
  ```

- Remove the .vSC.sh from your Gitlab certs folder:
  ```
  rm vSC.sh
  ```

  <b>Why did we have to move the script into the Gitlab certs folder if we're just going to copy it to another folder then delete it?</b>
  - Put simply, Synology DSM restricts SCP/SFTP to directories owned by you. By transferring from the Gitlab certs folder (owned by you), we can then transfer it to the Let's Encrypt certificate folder (owned by root). Alternatively, we could have changed the ownership of the Let's Encrypt folder from root to you, but that may cause unintended consequences.

## Testing/Running the Script

- Next, cd into the Let's Encrypt certifications directory, for example:
  ```
  cd /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERICSTRING
  ```

- Use this command to run the script:
  ```
  ./vSC.sh
  ```
  See [Using Custom Flags](#using-custom-flags) for advanced configurations.


- To test if the script worked, cd back into to your gitlab certs folder and check if a `vSC.log` file exists:
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


## Advanced Usage - Automation Through Crontab

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

More information on how to configure a crontab can be found here:
<a href="https://www.cyberciti.biz/faq/how-do-i-add-jobs-to-cron-under-linux-or-unix-oses/">Simplified how to add a job a crontab</a>
or
<a href="https://help.ubuntu.com/community/CronHowto">Crontab Manual</a>


## Using Custom Flags

In order to keep this script as flexible as possible, you can override default options with a flag, for example:
```
./vSC.sh -ls 2000 -gd /srv/docker/gitlab/ -led /etc/letsencrypt -lef b5TxhGe
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
          check if certificate expires in specified amount of days (default: 7)

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
          maximum vSC.log file size in bytes (default: 10000000)

     -h, -help
          help documentation
```

⚠️ NOTES:
- As noted above, using some flags will update other global variables since some of them rely on each other.
- If you have multiple certificate folders, then you'll need to use the `-lef` or `-letsencryptfolder` flag followed by the folder name.
