title: 常用Heap分析
date: 2017-12-29 23:23:31
categories: Java
tags: JVM
---

# 1. Heap统计信息

* 打印heap信息，如新老代大小，使用率。

```
jmap -heap <PID>
```

# 2. 对象统计信息

* 打印所有heap对象的统计信息，如对象的个数与所占大小。

```
// 打印所有对象的信息
jmap -histo PID > /tmp/histo.log

// 仅打印存活对象的信息
jmap -histo:live PID > /tmp/histo-live.log
```

> 不要随便加 -F 参数，可能把进程搞崩溃，仅当JVM已经假死状态，才用-F最后一搏。live参数实际效果是先执行一次Full GC清理掉已经过期的对象，因此要注意对线上业务的超时影响，尽量摘流量执行。

* 打印各个分代中的对象统计信息，见[TBJMap](https://github.com/alibaba/TBJMap) 

# 3. 获取HeapDump

```
// 获取所有对象的dump
jmap -dump:format=b,file=/tmp/heap.hprof <PID>

// 获取存活对象的dump，实际效果是先执行一次FULL GC
jmap -dump:live,format=b,file=/tmp/heap-live.hprof <PID>
```

> heap dump会造成JVM比较长时间的停顿，必须摘流量执行

dump文件一定要zip后再传输，节约不少时间

```
tar -zcf /tmp/heap.hprof.gz /tmp/heap.hprof
```

# 4. 分析HeapDump

使用JDK自带的VisaulVM(以jvisualvm启动)或Eclipse的MAT均可

留意对象有两个大小，很多时候`Retained Size`更有意义：

* 本身大小(Shallow Size)：对象本来的大小。
* 保留大小(Retained Size)： 当前对象大小 + 当前对象直接或间接引用到的对象的大小总和。

注意，Eclipse MAT分析时，如果想看到非存活状态的对象，需要特别勾选。

# 5. 分析HeapDump进阶

使用OQL进行高级查询。

* [VisualVM的OQL语法](https://visualvm.github.io/documentation.html)

# 6. Out Of Memory时自动HeapDump

OOM时生成HeapDump文件.
```
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${LOGDIR}/
```

