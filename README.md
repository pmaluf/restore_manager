# restore_manager

Script to automatic validate the backup of Oracle database 11g

## Notice

This script was tested in:

* Linux
  * OS Distribution: Red Hat Enterprise Linux Server release 6.5 (Santiago)
  * Oracle Database: 11gR2
  * GNU bash: 4.1.2

## Prerequisities

* Oracle Database 11gR2 installed

## How to use it

```
restore_manager.sh --help
# restore_manager.sh
# created: Paulo Victor Maluf - 09/2014
#
# Parameters:
#
#   restore_manager.sh --help
#
#    Parameter           Short Description                                                        Default
#    ------------------- ----- ------------------------------------------------------------------ --------------
#    --config-file          -c [REQUIRED] Config file with SID|DBNAME|DBID|NB_ORA_CLIENT
#    --help                 -h [OPTIONAL] help
#
#   Ex.: restore_manager.sh --config-file databases.ini
#
```

Example:
```
bash restore_manager.sh --config-file databases.ini
```

## Enable the init script

* Copy the script restore_manager to /etc/init.d/
```
$ cp restore_manager /etc/init.d/ && chmod +x /etc/init.d/restore_manager
```

* Setup the variables RESTORE_MANAGER and CONFIG_FILE with the restore_manager.sh and databases.ini path
```
$ vi /etc/init.d/restore_manager
RESTORE_MANAGER="/u00/scripts/oracle/restore/restore_manager.sh"
CONFIG_FILE="/u00/scripts/oracle/restore/databases.ini"
```

* Enable it with chkconfig
```
$ chkconfig restore_manager on
```

## License

This project is licensed under the MIT License - see the [License.md](License.md) file for details
