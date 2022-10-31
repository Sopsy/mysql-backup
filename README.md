# mysql-backup.sh
Backup script for MySQL databases. Mainly designed for InnoDB.

## Installation
1. Create a local user for backups
2. Create a database user for backups, give the following permissions: SELECT, LOCK TABLES, SHOW VIEW, PROCESS, TRIGGER, EVENT
3. Run mysql_config_editor to create .mylogin.cnf so the script does not request login details
4. chmod u+x mysql-backup.sh
5. ./mysql-backup.sh, verify output and backups in the same folder
6. Add to crontab or as a pre-command in your backup system (e.g. backuppc has pre-cmd)

## Known issues
None (tested only with <100GB databases)
