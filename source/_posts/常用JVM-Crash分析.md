title: 常用JVM Crash分析
date: 2017-12-29 23:25:21
categories: Java
tags: JVM
---

# 1. JVM 的Error文件

JDK在意外退出时，会该程序的运行目录生成一个hs_error_{PID}.log的Error文件，提供一些基本的信息。

```
-XX:ErrorFile=${LOGDIR}/hs_err_%p.log
```

# 2. CoreDump

在启动脚本中加入
```
ulimit -c unlimited
```

在进程意外退出时, 将生成CoreDump文件, 在该应用的执行目录下，有一个core.{PID} 文件。

如果没找到，进行全局搜索。

```
find / -name core.* 2>/dev/null
```

如果想固定目录，需要修改内核参数，修改/etc/sysctl.conf，增加

```
kernel.core_pattern=/apps/logs/core
```

获得coredump文件后，必须在服务器上，使用运行该应用的java, 可获得下列内容

* 获得threaddump

```
jstack /apps/svr/jdk/bin/java {coredump_file} > /tmp/threaddump.log
```

* 获得heapdump

```
jmap -dump:format=b,file=/tmp/heap.hprof /apps/svr/jdk/bin/java {coredump_file}
```

* gdb大法。



# 2 OOM Killer

```
dmesg | grep -i kill
```
可以看看有无OOM Killer信息

ps.dmesg中时间戳的转换

```
date -d "1970-01-01 UTC `echo "$(date +%s)-$(cat /proc/uptime|cut -f 1 -d' ')+{需转换的时间戳}"|bc ` seconds"
```


