# validateSSLCerts (vSC)

## Introduction

validateSSLCerts (vSC) is an automated bash script that attempts to validate and update a Lets Encrypt SSL certification generated from a Synology NAS (Let's Encrypt Authority X3 certificate). The certificate is not only being used by the Synology NAS, but is also being shared with a <a href="https://github.com/sameersbn/docker-gitlab">sameersbn/docker-gitlab</a> container. The idea is to seamlessly automate the process for updating the shared certificate across services with minimal downtime.

Please read my gist about Let's Encrypt with a Synology NAS running a Gitlab container before using this script: <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6">Let's Encrypt - Synology NAS + sameersbn/docker-gitlab</a>

⚠️ NOTE: This script is currently in the early beta stages!

## Requirements

- A Synology device that can generate a Let's Encrypt certificate
- A Synology user with system administrator access (ex: admin)
- A gitlab certs folder (for example: /volume1/docker/personal/gitlab/gitlab/data/certs)
- Inside the gitlab certs folder, there needs to be 4 files: `gitlab.key`, `gitlab.crt`, `dhparam.pem`, and a `cert.pem` (the cert.pem needs to be copied over from the Let's Encrypt certificate folder)
- OPTIONAL: For ease of use, I highly recommend adding <a href="https://synocommunity.com/">Synocommunity package sources</a> to your Synology's Package Center, then installing the Nano text editor on your device. Otherwise, you can use the not-so-user-friendly vi text editor.

## Installation and Usage

Download the latest version of vCS.sh to your Desktop by entering the following commands in a terminal window:
```
cd ~/Desktop && curl -O -L https://raw.githubusercontent.com/mattcarlotta/validateSSLCerts/master/vSC.sh
```

You must change the file permissions to make it executable:
```
chmod +x vSC.sh
```

You will then need to SFTP/SCP the script file from your Desktop into your gitlab data certs folder (<a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6">same as step 10 option 1 or option 2</a>)

Then open a terminal and SSH into your Synology NAS (replace synology_ip_address with your <b>Synology IP</b>) as a <b>system administrator</b>:
```
ssh admin@SYNOLOGY_IP_ADDRESS -- ex: ssh admin@192.168.1.55
```

Now, type the following command to elevate yourself to a root user:
```
sudo -s
```

Next, copy the file from the gitlab data certs folder to your Let's Encrypt certifications folder, for example (to find the RANDOM_ALPHANUMERICSTRING folder, follow <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6">step 9</a> ):
```
cp /volume1/docker/personal/gitlab/gitlab/data/certs /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERICSTRING
```

Next, cd into the Let's Encrypt certifications directory, for example:
```
cd /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERICSTRING
```

Lastly, use this command to run the script:
```
./vSC.sh
```

To test if the script worked, cd into to your gitlab certs folder and check if a `vCS.log` file exists:
```
cd /volume1/docker/personal/gitlab/gitlab/data/certs
ls
```

You can view the contents of the file by running:
```
nano vCS.log
```

## Advanced Usage - Automation through crontab

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

Now you'll want to add your own service, for example (the below will read as follows: "Every month, on every Monday within that month, at 1:30 in the morning, run the following command: path/to/script/vSC.sh as a root user"):
```
30      1       *       *       1       root    /usr/syno/etc/certificate/_archive/RANDOM_ALPHANUMERICSTRING/vSC.sh
```

More information on how to configure a crontab can be found here:
<a href="https://www.cyberciti.biz/faq/how-to-run-cron-job-every-minute-on-linuxunix/">Simplified how to run a crontab</a>
or
<a href="https://help.ubuntu.com/community/CronHowto">Crontab Manual</a>

## Using Custom Flags

In order to keep this script as flexible as possible, you can override default options with a flag, for example:
```
./vCS.sh -ls 2000 -gd /srv/docker/gitlab/ -led /usr/syno/etc/certificate/_archive/vCtu2Bm
```

You can view all of the custom flag options by running this command:
```
./vCS.sh -h
```

or find them here:
```
OPTIONS:
     Options below will overwrite their respective defaults (some may have side effects).

     -exp, -expires
          check if certificate expires in specified amount of days (default: 7)

     -gc, -gitcertdir
          Gitlab certificate directory folder (default: /volume1/docker/personal/gitlab/gitlab/data/certs)
          side effect: updates vCS.log directory

     -gd, -gitlabdir
          Gitlab directory folder (default: /volume1/docker/personal/gitlab)
          side effect: updates Gitlab certificate
          side effect: updates vCS.log directory

     -led, -letsencryptdir
          lets encrypt directory folder (default: /usr/syno/etc/certificate/_archive/0rOTRe)

     -ls, -logsize
          maximum vCS.log size in bytes (default: 10000000)

      -h
          help documentation
```

⚠️ NOTE: As noted above, using some flags will update other global variables since some of them rely on each other!


⚠️ This README is still under construction. More information will be added in the coming days to weeks. ⚠️
