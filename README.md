__This repository is DEPRECATED. Please don't use this backup script any longer.__

__The way better alternative is to use Duplycity (with duply)!__

----------------

# VestaCP Backup Manager


With the VestaCP Backup Manager you can easily manage all your Webserver backups created by the <a href="http://vestacp.com" target="_blank">Vesta Server Control Panel</a>



## Introduction
VestaCP creates by default a daily backup on the Server with all eMails, databases, webfolders and domain configurations.

This Manager is based on a __bash-script__ that you can run via a cronjob.

It downloads the backups from VestaCP to your local HDD and will delete older backups from the server automatically.

## Getting started
In order to use this script you just need to set up a ssh-key on your backup machine (e.g. a Raspberry Pi, local pc) and configure a cronjob.

### How to setup a ssh-key
If you did not already set up a ssh-key to access your server, you can find more information on the internet.

<a href="https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2" target="_blank">This is a simple tutorial.</a>


### How to setup a cronjob
Just login to your (local) backup machine and open a terminal.

1. Open the cronfile:
`sudo crontab -e`

2. Configure a backup job: `0 3 * * * /path/to/vestacp-backup-manager.sh`

3. Save and close the file.

The command above will run the script every day at 3:00 am.

<a href="https://help.ubuntu.com/community/CronHowto" target="_blank">Here you can find further information.</a>


## Settings
To get the script up and running, you just have to edit the settings in `vestacp-backup-manager.sh`:

`server`: the server adress (FQDN)

`user`: the ssh user to login on the server

`backupuser`: the VestaCP user whose backups are to be stored

`server_path`: the server path where the backups are saved from VestaCP

`local_path`: the local path where the backups should get downloaded to

`backup_on_server_days`: the amount of days the backups will remain on the server before they get deleted

`amount_local_backups`: the amount of backups that will be stored on the disk. If new backups are downloaded, the oldest will be deleted, so that only this amount of backups is stored on your local disk.

`max_download_retries`: the amount of maximum attempts to download a backup, if something gone wrong
