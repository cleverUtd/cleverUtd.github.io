title: Java Mission Control简介
date: 2016-09-04 11:55:59
categories: 
- Java
tags: 
- Jvm
---


最近在把一个重构完的项目放到beta环境测试时，顺带用了Java Mission Control(简称JMC)来分析jvm。第一次，发现确实好用，个人觉得作为要收费的JProfile的代替品已经足够用了。

# JMC

JDk7 7u40之后自带。主要有两种功能

- 实时监控JVM运行时的状态
- Java Flight Recorder 取样分析

# 实时监控

如果是远程服务器，使用前要开JMX
```
-Dcom.sun.management.jmxremote.port=${YOUR PORT}
-Dcom.sun.management.jmxremote 
-Dcom.sun.management.jmxremote.authenticate=false 
-Dcom.sun.management.jmxremote.ssl=false 
-Djava.rmi.server.hostname=${YOUR HOST/IP}
```


File -> Connetct -> Create A New Connection， 填入上面JMX参数的host和port，服务器账号密码。

![jmc_main_monitoring](http://7xp2k4.com1.z0.glb.clouddn.com/jmc_main_monitoring.png)