#!/bin/bash
#
#关闭selinux
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
#关闭防火墙
systemctl stop firewalld.service
systemctl disable firewalld.service
#安装常用软件
yum install -y vim net-tools psmisc wget lftp unzip bzip2 bash-completion rsync lrzsz sysstat
#更换yum源
cp -a /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
yum repolist
#时间同步
sed -i '$a */10 * * * * /usr/sbin/ntpdate -u ntp.aliyun.com >> /dev/null 2>&1' /etc/crontab
#添加host解析
sed -i '$a 192.168.252.11	k8s-master' /etc/hosts
sed -i '$a 192.168.252.12	k8s-node01' /etc/hosts
sed -i '$a 192.168.252.13	k8s-node02' /etc/hosts
#所有主机禁用swap交换分区
swapoff -a
sysctl -w vm.swappiness=0
sed -ri '/swap/d' /etc/fstab 
#所有主机调整系统的资源限制 
ulimit -SHn 65535
cat << EOF >> /etc/security/limits.conf
* soft nofile 655360
* hard nofile 131072
* soft nproc 655350
* hard nproc 655350
* soft memlock unlimited
* hard memlock unlimited
EOF
#所有主机配置docker仓库
cat << EOF > /etc/yum.repos.d/docker.repo 
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-stable-debuginfo]
name=Docker CE Stable - Debuginfo \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/debug-\$basearch/stable
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-stable-source]
name=Docker CE Stable - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/source/stable
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-test]
name=Docker CE Test - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/\$basearch/test
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-test-debuginfo]
name=Docker CE Test - Debuginfo \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/debug-\$basearch/test
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-test-source]
name=Docker CE Test - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/source/test
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-nightly]
name=Docker CE Nightly - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/\$basearch/nightly
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-nightly-debuginfo]
name=Docker CE Nightly - Debuginfo \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/debug-\$basearch/nightly
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-nightly-source]
name=Docker CE Nightly - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/source/nightly
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
EOF
#配置k8s仓库
cat << EOF > /etc/yum.repos.d/k8s.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
sed -ri -e '$d' -e '/^repo_/d' -e '/^gpgcheck/s|1|0|' /etc/yum.repos.d/k8s.repo
yum update -y
#所有主机安装ipvs
yum install ipvsadm ipset sysstat conntrack libseccomp -y 
#所有主机加载ipvs模块
cat << EOF > /etc/modules-load.d/ipvs.conf
ip_vs
ip_vs_lc
ip_vs_wlc
ip_vs_rr
ip_vs_wrr
ip_vs_lblc
ip_vs_lblcr
ip_vs_dh
ip_vs_sh
ip_vs_nq
ip_vs_sed
ip_vs_ftp
ip_vs_sh
nf_conntrack_ipv4
ip_tables
ip_set
xt_set
ipt_set
ipt_rpfilter
ipt_REJECT
ipip
EOF
systemctl enable --now systemd-modules-load
#调整内核参数
cat << EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
fs.may_detach_mounts = 1
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
net.netfilter.nf_conntrack_max=2310720

net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl =15
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 327680
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_conntrack_max = 65536
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_timestamps = 0
net.core.somaxconn = 16384
EOF
sysctl --system 


