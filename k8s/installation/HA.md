# 安装HAProxy、KeepAlived

规划的Master节点为3个，需要通过集群软件设置VIP节点，这里采用HAProxy + KeepAlived来配置HA。

在**所有**Master节点，按以下步骤安装。

## 安装程序包

直接通过`yum`命令安装即可。

`$ sudo yum install -y haproxy keepalived psmisc`

如果是离线安装，那么需要的依赖包比较多，不能遗漏。

```bash
# 离线安装要多出好几个依赖包
$ sudo yum install -y haproxy-1.5.18-9.el7.x86_64.rpm \
  keepalived-1.3.5-16.el7.x86_64.rpm \
  psmisc-22.20-16.el7.x86_64.rpm \
  lm_sensors-libs-3.4.0-8.20160601gitf9185e5.el7.x86_64.rpm \
  net-snmp-agent-libs-5.7.2-48.el7_8.1.x86_64.rpm \
  net-snmp-libs-5.7.2-48.el7_8.1.x86_64.rpm
```

## 创建工作目录

```bash
# 创建工作目录，赋权
$ sudo mkdir -p /ext/haproxy
$ sudo chown -R haproxy:haproxy /ext/haproxy
```

## 配置并启动HAProxy

### 编辑HAProxy配置文件

三个Master节点的配置文件内容相同，配置文件在`/etc/haproxy/haproxy.cfg`。

```bash
$ sudo vi /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
  log         /dev/log    local0
  log         /dev/log    local1 notice

  chroot      /ext/haproxy
  pidfile     /ext/haproxy.pid
  maxconn     4000
  user        haproxy
  group       haproxy
  daemon

  # turn on stats unix socket
  stats socket /ext/haproxy/haproxy-admin.sock mode 660 level admin
  stats timeout 30s
  daemon
  nbproc      1

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
  log                     global
  timeout connect         5000
  timeout client          1m
  timeout server          1m
  maxconn                 3000

#---------------------------------------------------------------------
# listen for admin_stats, use admin/123456 to login
#---------------------------------------------------------------------
listen    admin_stats
  bind    0.0.0.0:10080
  mode    http
  log     127.0.0.1  local0  err
  stats   refresh  30s
  stats   uri  /status
  stats   realm  welcome login\ Haproxy
  stats   auth   admin:123456
  stats   hide-version
  stats   admin if TRUE

#---------------------------------------------------------------------
# listen for kube-master
#---------------------------------------------------------------------
listen    kube-master
  bind    0.0.0.0:8443
  mode    tcp
  option  tcplog
  balance source
  server  192.168.176.35   192.168.176.35:6443  check  inter  2000  fall 2  rise 2 weight 1
  server  192.168.176.36   192.168.176.36:6443  check  inter  2000  fall 2  rise 2 weight 1
  server  192.168.176.37   192.168.176.37:6443  check  inter  2000  fall 2  rise 2 weight 1
```

其中配置有两段监听（listen）：

- admin_stats 为 haproxy的统计数据，用户名/口令设置为admin/123456。
- kube-master 为 kube-apiserver转发，采用tcp连接转发https。

### 启动HAProxy

在所有节点启动服务，并将其设置为开机自启动。

```bash
# 设置开机自启动
$ sudo systemctl enable haproxy
# 启动服务
$ sudo systemctl start haproxy
```

## 配置并启动KeepAlived

KeepAlived的作用在于创建VIP，并管理其漂移，VIP地址为`192.168.176.34`。

KeepAlived在多个节点中只选取一个主节点，因此主节点与备节点的配置文件内容不完全一样，配置文件位于`/etc/keepalived/keepalived.conf`。

### 编辑配置文件

```bash
# 主节点
$ cat /etc/keepalived/keepalived.conf
global_defs {
  router_id  lb-master-105
}

vrrp_script check-haproxy {
  script "killall -0 haproxy"
  interval 5
  weight -30
}

vrrp_instance  VI-kube-master {
  state MASTER
  priority 120
  dont_track_primary
  interface enp0s8
  virtual_router_id 68
  advert_int 3
  track_script {
    check-haproxy
  }
  virtual_ipaddress {
    192.168.176.34
  }
}

# 备节点
$ cat /etc/keepalived/keepalived.conf
global_defs {
  router_id  lb-master-105
}

vrrp_script check-haproxy {
  script "killall -0 haproxy"
  interval 5
  weight -30
}

vrrp_instance  VI-kube-master {
  state BACKUP
  priority 110
  dont_track_primary
  interface enp0s8
  virtual_router_id 68
  advert_int 3
  track_script {
    check-haproxy
  }
  virtual_ipaddress {
    192.168.176.34
  }
}
```

- 主备节点的router_id保持一致，vrrp_instance段名定义一致。
- 主备节点的state值不同，主节点为`MASTER`，备节点为`BACKUP`。
- 主备节点的priority值不同，数值越大，优先级越高。
- 主机vrrp_instance段的interface配置，必须指向有效的网卡配置名。

若追求完美配置，还应当修改服务单元文件（keepalived.service），让keepalived在haproxy之后启动。

### 启动KeepAlived

优先启动主节点，再启动各个备节点。

```bash
# 设为开机自启动
$ sudo systemctl enable keepalived
# 启动服务
$ sudo systemctl start keepalived
```
