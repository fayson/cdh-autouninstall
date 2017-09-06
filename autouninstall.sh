#!/bin/bash
#---------------------------------------------------
#脚本基于CDH5.x版本的一键自动卸载程序，基于如下环境
#	CDH安装方式为parcels模式
#	CDH版本为5.x版本
# 脚本需要在Cloudera Manager服务器上运行
# 脚本仅支持RHEL System
#Author peach
#Date	2017-05-17
#update 2017-08-23 简化输入参数
#---------------------------------------------------

#判断输入参数是否完整
if [ $# -lt 3 ]; then
	echo "params is can not be null."
	echo "username 1: 登录集群用户名"
	echo "longinType 2: 登录类型：key密钥文件,password密码登录,free免密认证"
	echo "password 3: 登录集群的认证文件或者密码,如果为密钥文件则确保文件权限为600"
	exit 1;
fi

CURRENTPWD=`pwd`
#集群所有节点文件
nodelist=$CURRENTPWD/node.list
##所有组件列表
componentlist=$CURRENTPWD/components.list
#集群各组件用户列表
userlist=$CURRENTPWD/user.list
#需要删除的目录列表
deletelist=$CURRENTPWD/delete.list
#登录用户名
username=$1
#集群登录方式key、password和 free
longinType=$2
#登录秘钥,key文件or密码
#秘钥文件权限为600 ，修改文件权限chmod 600 xxx.pem
password=$3
#获取当前服务器hostname
currentHost=`hostname`


#判断是否安装expect，参考http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script/677212#677212
if [ $longinType = "password" ]; then
  type expect > /dev/null 2>&1 || {
    echo "expect: command not found";
    echo "Please use command install: yum -y install expect";
    exit 1;
  }
fi

#参考 http://www.cnblogs.com/iloveyoucc/archive/2012/05/11/2496433.html
#自定义函数执行远程服务器命令
#需要注意的是，第一个EOF必须以重定向字符<<开始，第二个EOF必须顶格写，否则会报错。
function remote() {
  /usr/bin/expect <<EOF
    set timeout 10
    spawn ssh -t $1@$2 "$3"
    expect {
      "yes/no)?" {
        send "yes\r";exp_continue
      }
      "assword:" {
        send "$4\r";exp_continue
      }
    }
EOF
}

#停止Cloudera Server
echo "Stop Cloudera Scm Server................................."
sudo service cloudera-scm-server stop
sudo service cloudera-scm-server-db stop

#卸载Cloudera Manager Server和its数据库
echo "Uninstall Clouder Manager Server"
sudo yum remove cloudera-scm-server
sudo yum remove cloudera-scm-server-db

#一、停止集群所有节点的cloudera-scm-agent服务
scmAgentCmd="echo '[step 1] Stop cloudera-scm-agent service.....................';"
function stopClouderaScmAgernt() {
  sudo service cloudera-scm-agent hard_stop_confirmed
  scmAgentCmd=${scmAgentCmd}"sudo service cloudera-scm-agent hard_stop_confirmed;"
}


#二、卸载所有组件命令
componentsCmd="echo '[step 2] uninstall all components .........................';"
function executeRemoveComponents() {
  for component in `cat $componentlist`; do
    #在本机执行
    sudo yum -y remove $component
    componentsCmd=${componentsCmd}"sudo yum -y remove $component;"
  done
}

#三、clean yum
cleanYumCmd="echo '[step 3] clean yum...........................................';"
function cleanYum() {
  sudo yum clean all
  cleanYumCmd=${cleanYumCmd}"sudo yum clean all;"
}

#四、杀死所有组件用户进程脚本
killProcessCmd="echo '[step 4] kill all user process............................';"
function killUserProcess() {
  while read u
  do
    i=`cat /etc/passwd |cut -f1 -d':'|grep -w "$u" -c`;
    if [ $i -gt 0 ];then
      sudo kill -9 $(ps -u $u -o pid=);
      killProcessCmd=${killProcessCmd}"sudo kill -9 \$(ps -u $u -o pid=);"
    fi
  done < "$userlist"
}

#五、卸载cm_process
umountCmd="echo '[step 5] uninstall cm_process..................................';"
function umountCmProcesses() {
  sudo umount cm_processes;
  umountCmd=${umountCmd}"sudo umount cm_processes;"
}

#六、删除cm相关的信息，配置信息、依赖包、日志、yum缓存及运行、各组件依赖包等
deleteCmd="echo '[step 6] delete config、dependency、log and other information....';"
function deleteCmInfo() {
  while read line
  do
		content=`echo $line | awk '$0 !~ /#/ {printf($0)}'`
		if [ -n "$content" ]; then
			sudo rm -rf $line
	    deleteCmd=${deleteCmd}"sudo rm -rf $line;"
		fi
  done < $deletelist
}

#进行需要在所有节点执行的操作
for node in `cat $nodelist`; do
	echo "$node uninstall start..................................................."
	if [ $node = $currentHost ]; then
    stopClouderaScmAgernt
    executeRemoveComponents
    cleanYum
    killUserProcess
    umountCmProcesses
    deleteCmInfo
	else
		# cmds=`awk '$0 !~ /#/ {printf("%s", $0c);c=";"}END{print""}' cmd.list`
    # cmds=`awk '$0 !~ /#/ {printf("%s", $0c)}END{print""}' cmd.list`
    cmds=${scmAgentCmd}${componentsCmd}${cleanYumCmd}${killProcessCmd}${umountCmd}${deleteCmd}
		#执行远程命令
		echo "远程执行卸载命令:$node"
    if [ $longinType = "key" ]; then
      ssh -t -i $password $username@$node "$cmds"
    elif [ $longinType = "password" ]; then
      remote $username $node "$cmds" $password
    else
      ssh -t $username@$node "$cmds"
    fi
	fi

	echo "$node uninstall end....................................................."

done

echo "uninstall done"
