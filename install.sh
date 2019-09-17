#!/bin/bash


##############################################################################################################

#source env.properties

quick_install=N # $1
use_exist_media=Y # $2
docker_network=oracle_network # $3
db_file_name=oracle-database-xe-18c-1.0-1.x86_64.rpm # $4
db_version=18c # $5
db_sys_pwd=oracle # $6
db_port=31521 # $7
db_pdb_name=XEPDB1 # $8
em_port=35500 # $9
apex_file_name=apex_19.1.zip # $10
apex_version=19.1 # $11
apex_admin_username=ADMIN # $12
apex_admin_pwd='Welc0me@1' # $13
apex_admin_email='wfgdlut@gmail.com' # $14
ords_port=32513 # $15
ords_file_name=ords-19.2.0.199.1647.zip # $16
ords_version=19.2.0 # $17
aliyun_docker_account='' # $18
aliyun_docker_password='' # $19
tomcat_file_name=apache-tomcat-9.0.24.zip # $20


quick_install=$1

if [ "$quick_install" = "N" ]; then
  use_exist_media=$2
  docker_network=$3
  db_file_name=$4
  db_version=$5
  db_sys_pwd=$6
  db_port=$7
  db_pdb_name=$8
  em_port=$9
  apex_file_name=${10}
  apex_version=${11}
  apex_admin_username=${12}
  apex_admin_pwd=${13}
  apex_admin_email=${14}
  ords_port=${15}
  ords_file_name=${16}
  ords_version=${17}
  aliyun_docker_account=${18}
  aliyun_docker_password=${19}
  tomcat_file_name=${20}
  echo ">>> you choose custom install mode..."
else
  echo ">>> you choose quick install mode..."
fi;

echo ">>> print all of input parameters..."
echo $*
echo ">>> end of print all of input parameters..."

##############################################################################################################

echo ""
echo "--------- Step 1: Download installation media ---------"
echo ""


work_path=`pwd`

echo ">>> current work path is $work_path"

cd $work_path/docker-xe/files

if [ "$use_exist_media" = "Y" ]; then
  if [ ! -f $apex_file_name ]; then
    curl -o $apex_file_name https://cn-oracle-apex.oss-cn-shanghai-internal.aliyuncs.com/$apex_file_name
    #curl -o $apex_file_name https://cn-oracle-apex.oss-cn-shanghai.aliyuncs.com/$apex_file_name
  fi;
else
  if [ ! -f $apex_file_name ]; then
    echo ">>> cannot find $apex_file_name in $work_path/docker-xe/files/"
    pre_check="N"
  fi;
fi;

cd $work_path/docker-ords/files

if [ "$use_exist_media" = "Y" ]; then
  if [ ! -f $ords_file_name ]; then
    curl -o $ords_file_name https://cn-oracle-apex.oss-cn-shanghai-internal.aliyuncs.com/$ords_file_name
    #curl -o $ords_file_name https://cn-oracle-apex.oss-cn-shanghai.aliyuncs.com/$ords_file_name
    curl -o $tomcat_file_name http://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-9/v9.0.24/bin/apache-tomcat-9.0.24.zip
  fi;
else
  if [ ! -f $ords_file_name ]; then
    echo ">>> cannot find $ords_file_name in $work_path/docker-ords/files/"
    pre_check="N"
  fi;
fi;

cd $work_path/docker-xe/files
if [ "$use_exist_media" = "Y" ]; then
  if [ ! -f $db_file_name ]; then
    curl -o $db_file_name https://cn-oracle-apex.oss-cn-shanghai.aliyuncs.com/$db_file_name
  fi;
else
  if [ ! -f $db_file_name ]; then
    echo ">>> cannot find $db_file_name in $work_path/docker-xe/files/"
    pre_check="N"
  fi;
fi;


if [ "$pre_check" = "N" ]; then
  echo "Installation media files cannot be found..."
  exit;
fi;



##############################################################################################################

cd $work_path/docker-xe

if [ ! -d ../apex ]; then
  echo ">>> unzip apex installation media ..."
  mkdir ../apex
  cp scripts/apex-install*  ../apex/
  unzip -oq files/$apex_file_name -d ../ &
fi;

echo ""
echo "--------- Step 2: compile oracle xe docker image ---------"
echo ""


if [[ "$(docker images -q registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-xe:$db_version 2> /dev/null)" == "" ]]; then
  if [[ "$quick_install" = "Y" ]]; then
    echo ">>> docker image registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-xe:$db_version exists, pull from aliyun docker repository..."
    docker login --username=$aliyun_docker_account --password=$aliyun_docker_password registry-vpc.cn-shanghai.aliyuncs.com
    docker pull registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-xe:$db_version
  else
    echo ">>> docker image registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-xe:$db_version does not exist, begin to build docker image..."
    docker build -t registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-xe:$db_version --build-arg DB_SYS_PWD=$db_sys_pwd .
  fi;
else
  echo ">>> docker image registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-xe:$db_version is found, skip compile step and go on..."
fi;


echo ""
echo "--------- Step 3: startup oracle xe docker image ---------"
echo ""
docker run -d \
  -p $db_port:1521 \
  -p $em_port:5500 \
  --name=oracle-xe \
  --volume $work_path/oradata:/opt/oracle/oradata \
  --volume $work_path/apex:/tmp/apex \
  --network=$docker_network \
  registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-xe:$db_version


# wait until database configuration is done
rm -f xe_installation.log
docker logs oracle-xe >& xe_installation.log
while : ; do
    [[ `grep "Completed: ALTER PLUGGABLE DATABASE" xe_installation.log` ]] && break
    docker logs oracle-xe >& xe_installation.log
    echo "wait until oracle-xe configuration is done..."
    sleep 10
done

##############################################################################################################

echo ""
echo "--------- Step 4: install apex on xe docker image ---------"
echo ""

docker exec -it oracle-xe bash -c "source /home/oracle/.bashrc && cd /tmp/apex && chmod +x apex-install.sh && . apex-install.sh $db_sys_pwd $apex_admin_pwd $db_pdb_name $apex_admin_email"


##############################################################################################################

echo ""
echo "--------- Step 5: compile oracle ords docker image ---------"
echo ""

cd $work_path/docker-ords/

if [[ "$(docker images -q registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-ords:$ords_version 2> /dev/null)" == "" ]]; then
  echo ">>> docker image registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-ords:$ords_version does not exist, begin to build docker image..."
  docker build -t registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-ords:$ords_version .
else
  echo ">>> docker image registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-ords:$ords_version is found, skip compile step and go on..."
fi;



##############################################################################################################

echo ""
echo "--------- Step 6: startup oracle ords docker image ---------"
echo ""
docker run -d -it --network=$docker_network \
  -e TZ=Asia/Shanghai \
  -e DB_HOSTNAME=oracle-xe \
  -e DB_PORT=1521 \
  -e DB_SERVICENAME=$db_pdb_name \
  -e APEX_PUBLIC_USER_PASS=oracle \
  -e APEX_LISTENER_PASS=oracle \
  -e APEX_REST_PASS=oracle \
  -e ORDS_PASS=oracle \
  -e SYS_PASS=$db_sys_pwd \
  -e TOMCAT_FILE_NAME=$tomcat_file_name \
  --volume $work_path/oracle-ords/$ords_version/config:/opt/ords \
  --volume $work_path/apex/images:/ords/apex-images \
  -p $ords_port:8080 \
  registry-vpc.cn-shanghai.aliyuncs.com/kwang/oracle-ords:$ords_version

cd $work_path

echo ""
echo "--------- All installations are done, enjoy it! ---------"

##############################################################################################################
