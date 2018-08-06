# validateSSLCerts

Introduction

validateSSLCerts is an automated bash script that attempts to validate and update a Lets Encrypt SSL certification generated from a Synology NAS (Let's Encrypt Authority X3 certificate). This certificate is not only being used by the Synology NAS but is also being shared with a <a href="https://github.com/sameersbn/docker-gitlab">sameersbn/docker-gitlab</a> container. The idea is to seamlessly automate the process for updating the single certificate that the NAS uses and to make sure the Gitlab container utilizes any new incoming certifications with minimal downtime.

More information about Let's Encrypt with a Synology NAS running a Gitlab container can be found here: <a href="https://gist.github.com/mattcarlotta/4d9fdb90376c5d13db2c1b69a2d557a6">Let's Encrypt - Synology NAS + sameersbn/docker-gitlab</a>

⚠️ NOTE: This script in currently in the early alpha stages and is not ready to be used!
