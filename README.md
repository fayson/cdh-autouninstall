# cdh-autouninstall
前置条件：
1.脚本基于CDH5.x版本的一键自动卸载程序，基于如下环境
2.CDH安装方式为parcels模式
3.CDH版本为5.x版本
4.脚本需要在Cloudera Manager服务器上运行
5.脚本仅支持RHEL System

脚本输入参数说明：
username：登录集群的用户名
longinType：登录类型：key密钥文件,password密码登录,free免密认证
password：登录集群的认证文件或者密码,如果为密钥文件则确保文件权限为600


目录文件说明（以下文件不能重命名，否则会导致不脚本不能正常使用）：
autouninstall.sh 卸载脚本
components.list  集群中包含的所有组件
node.list  集群所有节点的hostname，必须为hostname
user.list  集群中所有启动服务的用户
