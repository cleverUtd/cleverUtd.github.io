title: TCP连接的建立和终止
date: 2017-03-27 17:30:10
categories: 网络编程
tags: TCP/IP
---


# 三路握手

建立一个TCP连接时，会发生下述情形：

1. 服务器通过调用 socket、bind、和listen函数完成。称作被动打开。

2. 客户端调用connect函数发起主动打开。期间客户发送一个SYN（同步）分节，它告诉服务器客户将在连接
中发送的数据的初始序列号

3. 服务器必须确认（ACK）客户的SYN，同时自己也要发送一个SYN分节，它含有服务器在同一连接
中发送的数据的初始序列号

4. 客户必须确认服务器的SYN


如图：
![TCP的三路握手](http://7xp2k4.com1.z0.glb.clouddn.com/three-way%20handshake.png)

客户端的初始序列号为J，服务器的初始序列号为K。

# TCP连接终止

1. 某个应用进程首先调用close，发送一个FIN分节，表示数据发送完毕。（主动关闭）

2. 接收到FIN的对端执行被动关闭。它的接收作为一个文件结束符（EOF）传递给接收端应用进

3. 一段时间后，接收到这个结束符的应用进程调用close关闭套接字。导致它的TCP也发送一个FIN。

4. 接收到这个最终FIN的原发送端TCP（即执行主动关闭的那一端）确认这个FIN。

![tcp连接关闭时的分组交换](http://7xp2k4.com1.z0.glb.clouddn.com/tcp%E8%BF%9E%E6%8E%A5%E5%85%B3%E9%97%AD%E6%97%B6%E7%9A%84%E5%88%86%E7%BB%84%E4%BA%A4%E6%8D%A2.jpg)

套接字被关闭时，所在端都要发送一个FIN，这是由应用程序调用close伴随发生的。

上图只是展示客户端主动关闭的情形。但是，，，需要注意！！！无论是客户端还是服务端，任何一端都可以执行主动关闭。

# TCP状态转换

![tcp状态转换图](http://7xp2k4.com1.z0.glb.clouddn.com/tcp%E7%8A%B6%E6%80%81%E8%BD%AC%E6%8D%A2%E5%9B%BE.jpg)

TCP为一个连接定义了11种状态，并且规定如何基于当前状态及在该状态下所接收的分节从一个状态转换到另一个状态。如上图所示，这些状态可以使用`netstat`显示。

# TIME_WAIT状态

执行主动关闭的那端都会经历这个状态，该端停留在这个状态的持续时间是最长分节生命期MSL的两倍。一般来说，TIME_WAIT状态的持续时间在1分钟到4分钟之间。

TIME_WAIT有两个存在的理由：
1. 可靠地实现TCP全双工连接的终止，TIME_WAIT确保有足够的时间让对端收到了ACK，如果被动关闭的那方没有收到Ack，就会触发被动端重发Fin，一来一去正好2个MSL

2. 允许老的重复分节在网络中消逝。有足够的时间让这个连接不会跟后面的连接混在一起（你要知道，有些自做主张的路由器会缓存IP数据包，如果连接被重用了，那么这些延迟收到的包就有可能会跟新连接混在一起）

具体可参考这篇文章 [TIME_WAIT and its design implications for protocols and scalable client server systems](http://www.serverframework.com/asynchronousevents/2011/01/time-wait-and-its-design-implications-for-protocols-and-scalable-servers.html)
