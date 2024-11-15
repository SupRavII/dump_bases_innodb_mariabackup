#!/bin/sh
# Full Backup and Restore with Mariabackup
# LIRE: https://mariadb.com/kb/en/library/full-backup-and-restore-with-mariabackup/
# dump_bases_innodb_mariabackup.sh
# Script de snapshot MariaDB avec mariabackup + Commandes de restauration et rapport par mail
#set -x
# Date du jour ( pour les repertoires )
Date=$(date "+%d-%m-%Y")
NOW=$(date "+%d-%m-%Y")
# variables
# destination des snapshots
Destination=/home/backupMariaDB
# Nombre d'historiques
Nb=8
# user MySQL root ou debian-sys-maint ou un utilisateur avec les bons privileges EX: xtrabackup
# https://mariadb.com/kb/en/mariabackup-overview/#authentication-and-privileges
#----------------------------------------------------------------------------------------------
# Preparation user MariaDB/MySQL
#----------------------------------------------------------------------------------------------
# CREATE USER 'xtrabackup'@'localhost' IDENTIFIED BY 'GROSMOTDEPASSEGROS';
# GRANT RELOAD, LOCK TABLES, PROCESS, REPLICATION CLIENT ON *.* TO 'xtrabackup'@'localhost';
# FLUSH PRIVILEGES;
#----------------------------------------------------------------------------------------------
User=xtrabackup
Pass=GROSMOTDEPASSEGROS
# Destinataire des rapports
Destinataire=DESTBACKUP@domain.tld
FromMAIL=root@localhost

# Verifier si la destination des backups existe.
if [ ! -d $Destination ]
then
  mkdir -p $Destination
fi
# Verifier si le programe zip est installe.
if [ -x /usr/bin/zip ]; then
    echo zip exit OK
else
    apt install zip
fi
# Verifier si le programe mariabackup est installe.
if [ -x /usr/bin/mariabackup ]; then
    echo mariadb-backup exit OK
else
    apt install mariadb-backup
fi

# Synchro MEM > DISQUE
sync
# Mariabackup necessite de commencer le snapshot dans un reperttoire vide
rm -rf  ${Destination}/${Date}
mkdir -p  ${Destination}/${Date}

# Suppression des backups de plus de 8 Jours y compris ceux compresses ( seconde ligne )
rm -rf $Destination/`date --date "$Nb days ago" "+%d-%m-%Y"`
rm -f $Destination/`date --date "$Nb days ago" "+%d-%m-%Y"`.zip

# Debut du snapshot
echo "== Backup Des Donnees MariaDB mariabackup =="
/usr/bin/mariabackup --backup \
	--user=$User \
	--password=$Pass \
	--target-dir=/$Destination/$Date/

echo "== Preparation Des Donnees MariaDB mariabackup pour restauration ulterieure =="
/usr/bin/mariabackup --prepare \
   --target-dir=/$Destination/$Date/

# Rapport sur la commande restauration a utiliser pour restaurer le serveur MariaDB complet.
rm -f $Destination/$Date/CMD_TO_RESTORE.txt
touch $Destination/$Date/CMD_TO_RESTORE.txt
echo "== Commande de restauration de ce Snapshot MariaDB ==" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "/etc/init.d/cron stop" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "cd $Destination" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "unzip $Date.zip" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "/etc/init.d/mysql stop" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "rm -rf /home/mysql-data.old ; mv /home/mysql-data /home/mysql-data.old ; mkdir -p /home/mysql-data ; chown -R mysql:mysql /home/mysql-data" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "/usr/bin/mariabackup --prepare --target-dir=/$Destination/$Date/" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "/usr/bin/mariabackup --copy-back --target-dir=/$Destination/$Date/" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "chown -R mysql:mysql /home/mysql-data" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "/etc/init.d/mysql start" >> $Destination/$Date/CMD_TO_RESTORE.txt
echo "/etc/init.d/cron start" >> $Destination/$Date/CMD_TO_RESTORE.txt

# Envoi de rapports par mail + commande de restauration de ce snapshot
rm -f $Destination/Rapports_Mariabackup.txt
touch $Destination/Rapports_Mariabackup.txt
cat $Destination/$Date/CMD_TO_RESTORE.txt >> $Destination/Rapports_Mariabackup.txt

# Envoi du rapport par mail.
var=$(ls -a $Destination/$Date/mysql/| sed -e "/\.$/d" | wc -l)
        echo $var
if [ $var -eq 0 ]; then
        echo $Date $var fichiers en backup MariaDB Mariabackup - KO | mail -s "Snapshot mariadb-backup sur `hostname` KO" -a "from: "$FromMAIL"" $Destinataire
        else
        echo $Date $var Fichiers dans le snapshot MariaDB Rep MySQL  sur `hostname` OK >> $Destination/Rapports_Mariabackup.txt
        ls -lha $Destination/$Date/ >> $Destination/Rapports_Mariabackup.txt
        echo $Date $var Fichiers dans le snapshot MariaDB Rep mysql sur `hostname` OK >>$Destination/Rapports_Mariabackup.txt
        cat $Destination/Rapports_Mariabackup.txt | mail -s "Backup mariadb-backup sur `hostname` - OK" -a "from: "$FromMAIL"" $Destinataire
fi


# Compression et suppression du repertoire de snapshot
cd $Destination/
# Debut LOG
echo "=================================================================" >>$Destination/Rapports_Mariabackup.txt
# Compression
echo "DEBUT Compression `date`" >>$Destination/Rapports_Mariabackup.txt
rm -f $NOW.zip
cd $Destination/
zip -r $NOW.zip $NOW
rm -rf $NOW
echo "FIN Compression `date`" >>$Destination/Rapports_Mariabackup.txt
echo "=================================================================" >>$Destination/Rapports_Mariabackup.txt

