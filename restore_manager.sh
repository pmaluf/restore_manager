#!/bin/bash
#
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
# Changelog:
#
# Date       Author               Description
# ---------- ------------------- ----------------------------------------------------
#====================================================================================

################################
# VARIAVEIS DE CONEXAO         #
################################
CATALOG_USER="rman"
CATALOG_PASS="mypassword"
CATALOG="rman"

################################
# VARIAVEIS GLOBAIS            #
################################
NLS_DATE_FORMAT="yyyy-mm-dd:hh24:mi:ss"
SQLPLUS=`which sqlplus`
RMAN=`which rman`
HOSTNAME=`hostname`
UNTIL_TIME="'sysdate-1'"
PFILE_TMP="${ORACLE_HOME}/dbs/initTEMP.ora"
MAIL_LST="oracle@mydomain"
SCRIPT_DIR=`pwd`
SCRIPT_NAME=`basename $1 | sed -e 's/\.sh$//'`
SCRIPT_LOGDIR="${SCRIPT_DIR}/logs"
LAST="${SCRIPT_LOGDIR}/last.log"
LOCK="${SCRIPT_LOGDIR}/${SCRIPT_NAME}.running"

################################
# FUNCOES                      #
################################
help()
{
  head -21 $0 | tail -19
  exit
}

rman_validate(){

RESTORE_TYPE=${1}
${RMAN} target / catalog ${CATALOG_USER}/${CATALOG_PASS}@${CATALOG} <<EOF

set dbid=${DBID}

RUN {
  set until time ${UNTIL_TIME};
  ALLOCATE CHANNEL ch00 TYPE sbt_tape;
  ALLOCATE CHANNEL ch01 TYPE sbt_tape;
  ALLOCATE CHANNEL ch02 TYPE sbt_tape;
  SEND 'NB_ORA_CLIENT=${NB_ORA_CLIENT}';
  restore ${RESTORE_TYPE} validate;
  RELEASE CHANNEL ch00;
  RELEASE CHANNEL ch01;
  RELEASE CHANNEL ch02;
}
EOF
}

sql()
{
sqlplus -s "/as sysdba" <<EOF
set pages 0
set define off;
set feedback off;
set lines 1000;
set trimout on;
${1}
EOF
}

restore_spfile(){
 log "Iniciando restore do spfile..."
 CHK_ERROR=`rman_validate "spfile from autobackup"  | tee -a ${LOGFILE}`

 if [[ ${CHK_ERROR} =~ (ORA-|RMAN-|ERRO) ]] && [[ ! ${CHK_ERROR} =~ (Finished restore at) ]]; then
   log "Falha ao restaurar o spfile." 1
  else
   log "SPFILE restaurado." 0
 fi
}

restore_controlfile(){
 log "Iniciando restore do controlfile..."
 CHK_ERROR=`rman_validate "controlfile" | tee -a ${LOGFILE}`

 if [[ ${CHK_ERROR} =~ (ORA-|RMAN-|ERRO) ]] && [[ ! ${CHK_ERROR} =~ (Finished restore at) ]]; then
   log "Falha ao restaurar o controlfile." 1
  else
   log "CONTROLFILE restaurado." 0
 fi
}

restore_database(){
 log "Iniciando restore dos database..."
 CHK_ERROR=`rman_validate "database" | tee -a ${LOGFILE}`

 if [[ ${CHK_ERROR} =~ (ORA-|RMAN-|ERRO) ]] && [[ ! ${CHK_ERROR} =~ (Finished restore at) ]]; then
   log "Falha ao restaurar o database." 1
  else
   log "Database restaurado com sucesso." 0
 fi
}

restore_archive(){
 log "Iniciando restore dos archives..."
 CHK_ERROR=`rman_validate "archivelog from time \"trunc(sysdate-1)\" until time \"trunc(sysdate)\""  | tee -a ${LOGFILE}`

 if [[ ${CHK_ERROR} =~ (ORA-|RMAN-|ERRO) ]] && [[ ! ${CHK_ERROR} =~ (Finished restore at) ]]; then
   log "Falha ao restaurar os archives." 1
  else
   log "ARCHIVES restaurados." 0
 fi
}


log (){
 if [ "$2." == "0." ]; then
   echo -ne "[`date '+%d%m%Y %T'`] $1 \t[\e[40;32mOK\e[40;37m]\n" | expand -t 70 | tee -a ${LAST}
 elif [ "$2." == "1." ]; then
   echo -ne "[`date '+%d%m%Y %T'`] $1 \t[\e[40;31mNOK\e[40;37m]\n" | expand -t 70 | tee -a ${LAST}
   send_email "${1}"
 else
     echo -ne "[`date '+%d%m%Y %T'`] $1 \n" | expand -t 70 | tee -a ${LAST}
 fi
}

parse(){
 SID=`echo ${1} | cut -d\| -f1`
 DBNAME=`echo ${1} | cut -d\| -f2`
 DBID=`echo ${1} | cut -d\| -f3`
 NB_ORA_CLIENT=`echo ${1} | cut -d\| -f4`
}

create_pfile(){
 log "Criando pfile: init${SID}.ora"
 sed "s/#DBNAME#/${DBNAME}/g" ${PFILE_TMP} > ${ORACLE_HOME}/dbs/init${SID}.ora
 if [ -f ${ORACLE_HOME}/dbs/init${SID}.ora ]
  then
   log "pfile criado com sucesso." 0
  else
   log "Falha ao criar o pfile: init${SID}.ora" 1
 fi
}

shutdown(){
 for INSTANCE in `ps -ef | grep ora_pmon | awk '{print $8}' | sed 's/ora_pmon_//g' | egrep -v '(grep|sed)'`
 do
  log "Verificando se existe alguma instancia iniciada..."
  if [ "${INSTANCE}" == "" ]
   then
    log "Instancia DOWN." 0
   else
    log "Baixando a instancia ${INSTANCE}..."
    export ORACLE_SID=${INSTANCE}
    CHK_ERROR=`sql "shutdown abort;"`
    if [[ ${CHK_ERROR} =~ (ORACLE instance shut down) ]]
     then
      log "Instancia ${INSTANCE} baixada com sucesso" 0
     else
      log "Falha ao baixar a instancia ${INSTANCE}." 1
    fi
  fi
 done
}

startup_nomount(){
 log "Iniciando database em NOMOUNT..."
 export ORACLE_SID=${SID}
 CHK_ERROR=`sql "startup nomount pfile='?/dbs/init${SID}.ora';"`
 if [[ ${CHK_ERROR} =~ (ORA-|RMAN-|ERRO) ]] && [[ ! ${CHK_ERROR} =~ (ORACLE instance started) ]]; then
   log "Falha ao iniciar a instancia ${SID}." 1
  else
   log "Instancia ${SID} iniciada com sucesso" 0
 fi
}

send_email(){
mail -s "[RESTORE][ORACLE] - ${SID}" ${MAIL_LST} <<EOF
${1}
EOF
}

help(){
  head -21 $0 | tail -19
  exit
}

# Verifica se foi passado algum parametro
[ "$1" ] || { help ; exit 1 ; }

# Tratamento dos Parametros
for arg
do
    delim=""
    case "$arg" in
    #translate --gnu-long-options to -g (short options)
      --config-file)             args="${args}-c ";;
      --help)                    args="${args}-h ";;
      #pass through anything else
      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
         args="${args}${delim}${arg}${delim} ";;
    esac
done

eval set -- $args

while getopts ":hc:" PARAMETRO
do
    case $PARAMETRO in
        h) help;;
        c) CONFIG_FILE=${OPTARG[@]};;
        :) echo "Option -$OPTARG requires an argument."; exit 1;;
        *) echo $OPTARG is an unrecognized option ; echo $USAGE; exit 1;;
    esac
done

while true
do
  if [ -f ${CONFIG_FILE} ]
   then
    grep -v "#" ${CONFIG_FILE} |
    while read line
    do
      parse $line
      LOGFILE=${SCRIPT_LOGDIR}/restore_${SID}.log
      create_pfile
      shutdown
      startup_nomount
      restore_spfile
      restore_controlfile
      restore_database
      restore_archive
      shutdown
    done
  fi
done
