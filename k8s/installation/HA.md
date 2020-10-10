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
