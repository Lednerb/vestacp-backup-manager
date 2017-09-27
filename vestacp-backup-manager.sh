#!/bin/bash
# Title: vestacp-backup-manager
# Author: Sascha Brendel
# Author's website: http://sascha-brendel.de
# Description: https://github.com/Lednebr/vestacp-backup-manager
# License: MIT, Copyright (c) 2015 Sascha Brendel
# License URL: https://github.com/Lednerb/vestacp-backup-manager/blob/master/LICENSE

#######################################################################
#                            SETTINGS                                 #
#######################################################################
#Serverdata
server="server.host.tld"
user="root"
backupuser="admin"

#Paths
server_path="/home/backup/"
local_path="/home/user/serverbackups/"

#Number of days
backup_on_server_days=7

#Number of local backups will be saved on the disk
amount_local_backups=21

#Maximum number of retries when download was not successful
max_download_retries=5

#######################################################################
#     END OF SETTINGS: You don't need to modify the lines below       #
#######################################################################

platform=`uname`
md5_gnu="md5sum"
md5_bsd="md5 -r"
md5=md5_gnu

if [[ $platform == 'FreeBSD' ]] ; then
	md5=md5_bsd
fi

#function echos actual etime
function etime {
	echo -n $(date +"%T") ''
}

#function reads and count all the local files
function get_local_backups {
	local_files=()
	amount_local=0
	for i in $(ls ${local_path} | grep ${backupuser}); do
		local_files+=($i)
		let amount_local=amount_local+1
	done
}

#Download the file and check validity with a MD5-Hash
function md5_secure_download { # expects $1 = ${files[$i]}
	retry_number=$2

	if [[ $retry_number < $max_download_retries ]]; then
		#Download file
		$(scp ${user}@${server}:${server_path}$1 ${local_path})

		#Check MD5-Hash to ensure, that the file was downloaded correctly
		localHash=$(${md5} $local_path$1 &2>1)
		remoteHash=$(ssh ${user}@${server} md5sum $server_path$1)

		if [[ ${localHash:0:32} == ${remoteHash:0:32} ]]; then
			etime
			echo ">>>>> MD5-Hash valid, file download was correct."
		else
			let retry_number=retry_number+1
			etime
			echo ">>>>> MD5-Hash is invalid, deleting local file..."
			$(rm $local_path$1)
			etime
			echo ">>>>> Local file was deleted successfully"
			etime
			echo ">>>>> Retry download..."
			md5_secure_download $1 $retry_number
		fi
	fi
}

echo "========================================================================="
	let space=(73-${#backupuser}-28)/2

	for (( i = 0; i < $space; i++ )); do
		echo -n ' '
	done

etime
echo "Manage backups of: "$backupuser

echo "========================================================================="
echo "               +++ Avialabe backups on the Server +++"
echo "-------------------------------------------------------------------------"


#Print filenames of all backups on the server from the chosen backup user
	files=()
	filedates=()
	for i in $(ssh ${user}@${server} ls ${server_path} | grep ${backupuser}); do
		echo $i
		files+=($i)
		filedates+=(${i:${#backupuser}+1:10})
	done


echo
echo "-------------------------------------------------------------------------"
echo "                      +++ Latest backup status +++"
echo "-------------------------------------------------------------------------"

#Check, if there are new backups on the server

	#get latest local backup
	get_local_backups
	if [[ ${#local_files[@]} -ne 0 ]]; then
		latest_local_file=${local_files[$((${#local_files[@]} - 1))]} #get last array entry
	#if there isn't any, avoid script-errors
	else
		latest_local_file=0
	fi


	#if there are local files
	if [[ $latest_local_file  != 0 ]]; then
		#get date of the latest local file
		latest_local_file_date=${latest_local_file:${#backupuser}+1:10}

		#foreach all remote files
		counter=0
		for i in "${filedates[@]}"; do

			#compare if there are new backups, if yes, start download
			if [[ $i > $latest_local_file_date ]]; then
				#Start download from the remote server
				etime
				echo "> Starting download: " ${files[$counter]}
				md5_secure_download ${files[$counter]}
			fi
			let counter=counter+1
		done
	fi



	#Initial download, just download the latest amount_local_backups backups to the disk
	if [[ ${#local_files[@]} -eq 0 ]]; then

		start=$((${#files[@]} - amount_local_backups))
		if [[ $start -lt 0 ]]; then
			start=0
		fi

		for (( i = $start; i < ${#files[@]}; i++ )); do
			#Start download from the remote server
			etime
			echo "> Starting download: " ${files[$i]}
			md5_secure_download ${files[$i]}
		done
	fi

	etime
	echo "> Latest backup actually downloaded!"

echo
echo "-------------------------------------------------------------------------"
echo "                      +++ Remote backup status +++"
echo "-------------------------------------------------------------------------"

#Delte file from server after backup_on_server_days

	#Actual date
	date=$(date +%F)

	#calculate last day, before backups will be deleted
	if [[ $platform == 'FreeBSD' ]]; then
		delete_date=$(date -v-"${backup_on_server_days}"d +%F)
	else
		delete_date=$(date -d "${backup_on_server_days} days ago" +%F)
	fi

	#foreach all remote files, save outdated files in array
	outdated_files=()
	counter=0
	for i in "${filedates[@]}"; do
		if [[ $i < $delete_date ]]; then
			outdated_files+=(${files[$counter]})
		fi
		let counter=counter+1
	done

	#if outdated files were found, delete them
	if [[ ${#outdated_files[@]} -ne 0 ]]; then
		etime
		echo "> Outdated backups found on the server!"
		etime
		echo "> Starting to delete them..."

		for i in "${outdated_files[@]}"; do
			$(ssh ${user}@${server} rm $server_path$i)
			etime
			echo "> Deleted" $i
		done

		etime
		echo "> Deleted all outdated backups."
	else
		etime
		echo "> No outdated backups left on the server."
	fi


echo
echo "-------------------------------------------------------------------------"
echo "                    +++ Local backup status +++"
echo "-------------------------------------------------------------------------"

#Check local backups, remove files if there are more than specified in amount_local_backups
	get_local_backups
	etime
	echo ">" $amount_local "out of" $amount_local_backups "backups are currently saved on the disk"

	#if there are more backups as it's specified, delete them
	if [[ $amount_local -gt $amount_local_backups ]]; then
		amount_to_delete=$((amount_local - amount_local_backups))

		if [[ $amount_to_delete -ne 0 ]]; then
			etime
			echo "> That are" $amount_to_delete "too much, start deleting files..."

			#Delete the amount_to_delete oldest files from local disk
			for (( i = 0; i < $amount_to_delete; i++ )); do
				$(rm ${local_path}${local_files[i]})
				etime
				echo "> Deleted" ${local_files[i]}
			done

			get_local_backups
			etime
			echo ">" $amount_local "out of" $amount_local_backups "backups are currently saved on the disk"
		fi
	fi

echo
echo
