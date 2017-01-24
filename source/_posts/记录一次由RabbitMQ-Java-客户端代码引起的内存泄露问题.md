title: 记录一次内存泄露排查过程
date: 2017-01-23 18:06:05
categories: Java
tags: JVM
---

最近线上某个项目发生内存泄露，JVM忙于GC，导致业务线程基本不执行。经过排查最终发现是RabbitMQ的Java客户端代码导致的。现把排查过程记录下来

### 问题背景

某日，线上的RabbitMQ发现有大量消息堆积，迟迟未能出队。Tomcat没有发现异常报错，却在输出的日志中发现处理1000条消息要耗时几十分钟不等（正常情况只需3~5秒）。

### 排查

通过 `top` 命令发现进程占用较高CPU，然后 `top -Hp` 发现进程中有四条线程一直处于繁忙，分析了一下，具体怎么分析？参考[Linux下如何对Java线程进行分析](https://www.zhihu.com/question/20238208)

这四条线程的信息都是一样
```
"GC task thread#0 (ParallelGC)" prio=10 tid=0x083d2c00 nid=0x57bd runnable 
```

说明进程一直忙于GC。大部分时间STW，业务线程基本不执行。

那为什么会一直在GC呢？ 有几个可能，一是heap设置得过小，而又要频繁分配对象；二是内存泄露，对象一直不能被回收。由于我们的heap设置了512M其实也不算少，于是矛头直指内存泄漏。

然后通过 `jstat -gcutil pid`发现年轻代和年老代都是99%的占用率，而且不能被回收，确实是内存泄露。

确定问题原因后，下一步就要分析一下 java heap，找出什么对象发生泄露。于是赶紧执行命令`jmap -dump:live,format=b,file=heap.prof pid`把heap dump下来进行分析,live选项会先执行一次
full gc保证dump下来的都是存活的对象。

dump 下来后，执行 `jhat heap.prof`，然后打开浏览器查看结果，分析发现，com.rabbitmq.client.recovery.RecoveryAwareChannelN和com.rabbitmq.client.QueueingConsumer的对象数量有20w+，多得惊人。
而且数量一样。于是大胆猜测，这两者应该存在一个引用关系，所以数量才会一样。而可能是channel，也可能是comsumer还有被别的对象引用这导致一直不能被回收，所以导致内存泄露。

注意：jhat其实是一个很简陋的分析工具，如果通过其找不出头绪，推荐使用Eclipse的MAT插件或者JDK自带的VisualVM分析会更好。

大胆猜测过后，就是小心验证了。首先来看一下我们使用RabbitMQ Java Client处理消息的代码，

```
Channel channel = connection.createChannel();
channel.queueDeclare(queueName);
QueueingConsumer consumer = new QueueingConsumer(channel);
channel.basicConsume(queueName, false, consumer);

try{
int count = 1;
while(count < 1000) {
    QueueingConsumer.Delivery delivery = consumer.nextDelivery(500);
    ...
    ...
    各种业务逻辑
    ...
    ...
    }
} catch(Exception e) {
    e.printStackTrace();
} finally {
    channel.close();
}
```

总体的处理流程就是如上代码所示，有几点需要注意：

1. Channel是个接口，设置automaticRecoveryEnalbed为true后，实现类是RecoveryAwareChannel
2. channel是QueueingConsumer的一个属性，即QueueingConsumer引用着channel，这也证明了之前的猜测。
3. 每一轮最多处理1000条消息，处理完之后只close掉channel，没有close connection。

感觉离真相越来越近了，在知道了consumer引用着channel之后，那就是说明还有别的地方引用consumer，导致不能被回收。那么究竟哪里会引用consumer呢，这时就要继续深入，查看源码。
于是发现basciConsume方法中调用了一个叫recordConsumer方法：
```
private void recordConsumer(String result,
                                String queue,
                                boolean autoAck,
                                boolean exclusive,
                                Map<String, Object> arguments,
                                Consumer callback) {
        RecordedConsumer consumer = new RecordedConsumer(this, queue).
                                            autoAck(autoAck).
                                            consumerTag(result).
                                            exclusive(exclusive).
                                            arguments(arguments).
                                            consumer(callback);
        this.connection.recordConsumer(result, consumer);
    }
```
QueueingConsumer被RecordedConsumer引用，而RecordedConsumer又被connection引用着。

再看channel.close方法：
```
public void close() throws IOException, TimeoutException {
        try {
          delegate.close();
        } finally {
          this.connection.unregisterChannel(this);
        }
    }
```

到这里，其实就已经清楚了，当channel被close后，connection仍然引用着RecordedConsumer，所以QueueingConsumer不能被释放掉。

那就是说，这有可能是官方客户端的坑，于是上网搜了一下，发现github已经有issue，[issue #208](https://github.com/rabbitmq/rabbitmq-java-client/issues/208),
而且已经在3.6.6版本fix了，因为我们用的是3.6.3，所以赶紧升级版本。测试一番后，确实不会泄露了，问题解决。

3.6.6的close方法源码：
```
@Override
      public void close() throws IOException, TimeoutException {
          try {
             delegate.close();
          } finally {
             for (String consumerTag : consumerTags) {
                 this.connection.deleteRecordedConsumer(consumerTag);
             }
             this.connection.unregisterChannel(this);
          }
      }
```
可以看出，在fix后的代码中，当关闭channel时，会先把该channel相关的RecordedConsumer先删除掉，这就避免了内存泄漏。

### 总结

虽然这是我们用的RabbitmqMQ Java Client版本太旧所引起的问题，而官方其实也已经fix了。但发生内存泄露时，分析排查的思路基本都是一致的。

我们也要学会运用好jdk自带的各种命令工具来分析有关jvm的问题。