title: Java Mission Control之使用
date: 2016-09-04 11:55:59
categories: 
- Java
tags: 
- Jvm
---


最近在把一个重构完的项目放到beta环境测试时，
顺带实践了一下Java Mission Control(简称JMC)来分析jvm。发现确实好用，个人觉得作为要收费的JProfile的代替品已经足够用了。

JMC可以看的东西太多，选一些自己觉得最有用的来总结一下：


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

通过“+”按需添加各种统计图表


### Action

![Triggets](http://7xp2k4.com1.z0.glb.clouddn.com/jmc_triggers.png)

可以选择各种Action，Condition设置条件，条件达到Action就会被触发。

例如，你可以设置heap dump当接近memory limit；又或者在CPU高消耗期间触发 JFR recoding了解发生了什么鬼。

另外action也可以选择log或者发送邮件的方式


### Memory

![Memory](http://7xp2k4.com1.z0.glb.clouddn.com/jmc_memory.png)

内存tab提供heap和GC的信息。个人最主要看GC次数、时间；以及随着GC发生heap的内存变化情况，以便来调整jvm参数进行优化。

### Threads

![Threads](http://7xp2k4.com1.z0.glb.clouddn.com/jmc_threads.png)

主要看每条线程所占的CPU、死锁检测以及线程是被哪个代码阻塞的(Lock Name)


# Flight Recorder

要使用取样，需要先添加参数

```
-XX:+UnlockCommercialFeatures 
-XX:+FlightRecorder
```

取样时间默认1分钟，可自行按需调整，事件设置选为profiling，然后可以设置都需要profile哪些信息，比如：

- 加上对象数量的统计：Java Virtual Machine->GC->Detail->Object Count/Object Count after GC
- 方法调用采样的间隔从10ms改为1ms(但不能低于1ms，否则会影响性能了): Java Virtual Machine->Profiling下的两个选项
- Socket与File采样, 10ms太久，但即使改为1ms也未必能抓住什么，可以干脆取消掉: Java Application->File Read/FileWrite/Socket Read/Socket Write

然后就开始Profile，到时间后Profile结束，会自动把记录下载回来，在JMC中展示。

### General

JVM Information tab包含所有JVM 参数，可以在这里查看，当然也可以在服务器上通过 `XX:+PrintFlagsFinal` 查看

### Memory

GC详细信息（Garbage Collections、GC Times）- gc次数，每次gc时的详细信息，几时发生gc，什么gc，持续时间，clean了多少空间等

内存分配（Allocations） - 让对象分配情况无所遁形。 按类、按线程、对象的创建调用栈来查看对象创建情况，  可以看到TLAB内/外的分配情况（每条线程在Heap里分了一个Thread Local Area，在TLAB里的内存分配不需要线程竞争）

一般来说，尽可能确保以下几点，你的程序会跑得更快：
- 分配更少的对象
- 尽可能少进行 full gc
- 尽可能少在TLAB外分配对象 
 
### Code

Hot packages： 热点packages统计，看以看每个Java package的耗时

Hot classes：热点class统计，能看出哪个class最耗CPU

### Threads

- Contention：线程争夺，统计哪些线程被哪些方法阻塞，阻塞多久
- Lock Instances：展示哪些锁实例会导致线程争夺

要提高吞吐量，可以根据以上两点来做优化



参考：

[java-performance.info上的介绍文章](http://java-performance.info/oracle-java-mission-control-overview)
[另一份Java应用调优指南之－工具篇](http://calvin1978.blogcn.com/articles/perf-tunning-2.html)