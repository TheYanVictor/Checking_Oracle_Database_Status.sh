#!/bin/bash

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     About      ------------------------------------------------------
#Goal: To check relevant parameters both DB and S.O.
#Developer: Yan Victor R. Marostegan

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Logging     -----------------------------------------------------
#Log file - full version
LOG_FILE="/tmp/chk_db.log"
exec >> >(tee -a "$LOG_FILE") 2>&1

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Main banner     -------------------------------------------------
acc_date=$(date +"%Y-%m-%d")
echo "**************************************************************************************************"
echo "******************************   DATABASE INSPECTION   *******************************************"
echo "**************************************************************************************************"
echo
echo
echo "Here you will find some relevant information about the database status in $acc_date, please bare in mind that particularities in 
your environment may require adjustments in this script"
echo
echo

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     BASH PROFILE     ------------------------------------------------
chk_bash()
{
#Variables for comparing the bash_profile
rman_value="alias rman='rlwrap rman'"
sqlplus_value="alias sqlplus='rlwrap sqlplus'"
mv_value="alias mv='mv -i'"
cp_value="alias cp='cp -i'"
rm_value="alias rm='rm -i'"
oratop_value="alias start_oratop='\$ORACLE_HOME/suptools/oratop/oratop -f -i2 / AS SYSDBA'"
msg_error="The actual value is: "

#Local banner
echo "****************************************************************************************************************"
echo
echo "Comparing bash profile:"
echo

##RMAN
acc_rman=$(grep rman /home/oracle/.bash_profile)
#Compare
if [ "$rman_value" = "$acc_rman" ]; then
    echo "RMAN	OK"
else
    echo "RMAN	NOT OK $msg_error $acc_rman" 
fi

##SQLPLUS
acc_sqlplus=$(grep sqlplus= /home/oracle/.bash_profile)
#Compare
if [ "$sqlplus_value" = "$acc_sqlplus" ]; then
    echo "SQLPLUS	OK"
else
    echo "SQLPLUS	NOT OK $msg_error $acc_sqlplus"
fi

##MV 
acc_mv=$(grep mv= /home/oracle/.bash_profile)
#Compare
if [ "$mv_value" = "$acc_mv" ]; then
    echo "MV	OK"
else
    echo "MV	NOT OK $msg_error $acc_mv"
fi

##CP  
acc_cp=$(grep cp /home/oracle/.bash_profile)
#Compare
if [ "$cp_value" = "$acc_cp" ]; then
    echo "CP	OK"
else
    echo "CP	NOT OK $msg_error $acc_cp"
fi

##RM  
acc_rm=$(grep rm= /home/oracle/.bash_profile)
#Compare
if [ "$rm_value" = "$acc_rm" ]; then
    echo "RM	OK"
else
    echo "RM	NOT OK $msg_error $acc_rm"
fi

##ORATOP   
acc_oratop=$(grep start_oratop /home/oracle/.bash_profile)
#Compare
if [ "$oratop_value" = "$acc_oratop" ]; then
    echo "ORATOP	OK"
else
    echo "ORATOP	NOT OK $msg_error $acc_oratop"
fi
}

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Multiplexed Redo     --------------------------------------------
chk_redo()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Multiplexed Redo:"
echo

#Capture selected lines from the output
number_groups=$(echo "SELECT GROUP# FROM V\$LOG;" | $ORACLE_HOME/bin/sqlplus -S / AS SYSDBA | head -n -2 | tail -n +4 | wc -l)

number_members=$(echo "SELECT GROUP# FROM V\$LOG;" | $ORACLE_HOME/bin/sqlplus -S / AS SYSDBA | head -n -2 | tail -n +4 | wc -l)

#The tail -n +4 removes the first three lines of sqlplus output (SQLPlus banner and login information), and head -n -2 removes the last 2 lines (SQLPlus prompt)

#Considering it multiplexed
double_group=$((2 * number_members))

#The number of members must be at least the double of groups, so every logfile is multiplexed
if [ "$double_group" -ge "$number_groups" ]; then
    echo "RedoLogs		OK"
else
    echo "RedoLogs		NOT OK $msg_error $double_group"
fi
}


#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Controlfile     -------------------------------------------------
chk_control()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Controlfile:"
echo

#Get the number of controlfiles (it must be greater than 2 in order to be multiplexed)
number_control=$(
	$ORACLE_HOME/bin/sqlplus -S / AS SYSDBA << EOF
	SET HEADING OFF
	SET TIMING OFF
	SELECT COUNT(*) FROM v\$controlfile;
	EXIT;
EOF
)

#Implementation
if [ "$number_control" -eq 2 ]; then
	echo "Controlfile is multiplexed"
else
	echo "Controlfile is NOT multiplexed"
fi
}
#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     GLogin     ------------------------------------------------------
chk_glogin()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "GLogin:"
echo

#Text variables
echo "SET PAGESIZE 1000
SET LINESIZE 220
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED
DEFINE _EDITOR = /usr/bin/vim
COLUMN segment_name FORMAT A30 WORD_WRAP
COLUMN object_name FORMAT A30 WORD_WRAP
SET TIMING ON
SET TIME ON
SET SQLPROMPT \"_USER'@'_CONNECT_IDENTIFIER > \"

COL DISK_GROUP_NAME FORMAT A30
COL DISK_FILE_PATH FORMAT A30
COL DISK_FILE_NAME FORMAT A30
COL DISK_FILE_FAIL_GROUP FORMAT A30
COL DATAFILE FORMAT A70;

COL USERNAME FORMAT A10;
COL MACHINE FORMAT A20;
COL OSUSER FORMAT A15;
COL SPID FORMAT A8;
COL PROGRAM FORMAT A15;

col job_name format a20;
Col STATE format a10;
col start_date format a40;
col NEXT_RUN_DATE format a40;" > prompt_model.txt

#Implementation
echo
echo "Whats's different: "
echo 
diff $ORACLE_HOME/sqlplus/admin/glogin.sql prompt_model.txt
echo "-----------------------------------------------------------------------------------------------------"
}

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Crontab     -----------------------------------------------------
chk_crontab()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Crontab:"
echo

echo "## BKP LOGICO - 01H
00 01 * * * sh -x /home/oracle/bin/scripts/bkp_logico.sh > /tmp/bkp_logico.log 2>&1

## BKP RMAN - 21H
00 21 * * * sh -x /home/oracle/bin/scripts/bkp_fisico.sh > /tmp/bkp_fisico.log 2>&1

#Backup Archives
*/15 * * * * sh -x /home/oracle/bin/scripts/bkp_archives.sh > /tmp/bkp_archives.log 2>&1

## REPORT EMAIL
00 06 * * * sh -x /home/oracle/bin/scripts/ccm_report_bkp/check_bkp_html1.sh > /tmp/ccm_report.log 2>&1

## Coleta de estatisticas - Diario
00 18 * * * sh -x /home/oracle/bin/scripts/estatisticas_diario.sh > /tmp/estatisticas_diario.log 2>&1

## Coleta de estatisticas - Semanal - Carga
00 10 * * 3 sh -x /home/oracle/bin/scripts/estatisticas_semanal_carga.sh > /tmp/estatisticas_semanal_carga.log 2>&1

## Limpar traces antigos
00 06 * * * sh -x /home/oracle/bin/scripts/clean_logs_old.sh > /tmp/clean_logs_old.log 2>&1

## Limpar snapshot de statspack
#00 20 * * * sh -x /home/oracle/bin/scripts/clean_staspack.sh > /tmp/clean_statspack.log 2>&1

##VALIDATE BACKUP RMAN - PREVENTIVA
#00 03 27 * * sh -x /home/oracle/bin/scripts/auto_validate.sh > /tmp/auto_validate_preventiva.log 2>&1" > crontab_model

#Implementation
crontab -l > acc_cron

echo "What's missing in Crontab: "
echo

#This gets the differece in these files
error_check=$(comm -13 --nocheck-order crontab_model acc_cron)

# Check if the error_check variable is empty
if [ -z "$error_check" ]; then
    echo "No error was found."
else
    echo "Errors found:"
	echo "$error_check"
fi

rm -f crontab_model
}

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Logical backup     ----------------------------------------------
chk_dump()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Logical backup:"
echo

#Implementation
acc_date=$(date +"%Y-%m-%d")
if find /u02/bkp_logico/ -name "BKP_*_$acc_date.tgz" -print -quit | grep -q .; then
    echo "Most recent logical backup exists"
else
	acc_date=$(date -d "yesterday" +"%Y-%m-%d")
	if find /u02/bkp_logico/ -name "BKP_*_$acc_date.tgz" -print -quit | grep -q .; then
		echo "Logical backup found from: $acc_date"
	else 
		echo "No logical backup found in the last two days"
	fi
fi
}
#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Fisical backup     ----------------------------------------------
chk_rman()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Fisical backup:" 

#Variables
pattern="BKP_*.bkp"  # Pattern to match files
directory="/u02/fra"  # Directory to search in 

#Implementation
find "$directory" -type f -name "$pattern" | while IFS= read -r file; do
    modification_date=$(stat -c %Y "$file")
    formatted_date=$(date -d @"$modification_date" +"%Y-%m-%d %H:%M:%S")
    echo "File: $file, Last Modified: $formatted_date"
done


}

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Force Logging     -----------------------------------------------
chk_force_loggin()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Force Logging:"
#Implementation
	$ORACLE_HOME/bin/sqlplus -S / AS SYSDBA << EOF
	SET HEADING OFF
	SET TIMING OFF
	SELECT FORCE_LOGGING FROM V\$DATABASE;
	EXIT;
EOF
}
#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Alert Log     ---------------------------------------------------
chk_alert_log()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Alert Log:"
echo

#Implementation
if find /home/oracle -name alert*.log -print -quit | grep -q .; then
    echo "Alert log is on Oracle Home"
else
	echo "Alert log is NOT on Oracle Home"
fi
}

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Statspack     ---------------------------------------------------
chk_statspack()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "Statspack:"
echo

#Implementation
# Array containing the names of the required files
required_files=("spcreate.sql" "spauto.sql" "spreport.sql" "spdrop.sql")

# Flag to track whether all files are found
all_files_found=true

# Check if each required file exists
for file in "${required_files[@]}"; do
    if [ ! -f "$ORACLE_HOME/rdbms/admin/$file" ]; then
        echo "Error: $file not found"
        all_files_found=false
    fi
done

# Check the flag to determine the response
if [ "$all_files_found" = true ]; then
    echo "Statspack files found"
else
    echo "Statspack files NOT fully found"
fi
}

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     FILESYSTEMIO_OPTIONS     ----------------------------------------
chk_filesystemio_options()
{
#Local banner
echo "****************************************************************************************************************"
echo
echo "FILESYSTEMIO_OPTIONS:"
#Implementation
	$ORACLE_HOME/bin/sqlplus -S / AS SYSDBA << EOF
	SET HEADING OFF
	SET TIMING OFF
	SELECT value FROM v\$parameter WHERE name = 'filesystemio_options';
	EXIT;
EOF
}

#----------------------------------------------------------------------------------------------------------------------
#------------------------------------------------     Calling the functions     ---------------------------------------
chk_bash
chk_redo
chk_control
chk_glogin
chk_crontab
chk_dump
chk_rman
chk_force_loggin
chk_alert_log
chk_statspack
chk_filesystemio_options

