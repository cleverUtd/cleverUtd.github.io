title: RabbitMQ之Qos prefetch
date: 2016-09-15 18:19:11
categories: 消息队列
tags: RabbitMQ
---

实际使用RabbitMQ过程中，如果完全不配置QoS，这样Rabbit会尽可能快速地
发送队列中的所有消息到client端。因为consumer在本地缓存所有的message，
从而极有可能导致OOM或者导致服务器内存不足影响其它进程的正常运行。所以我们
需要通过设置Qos的prefetch count来控制consumer的流量。同时设置得当也会提高consumer的吞吐量。

## prefetch与消息投递

prefetch允许为每个consumer指定最大的unacked messages数目。简单来说就是用来指定一个consumer一次可以从Rabbit中获取多少条message并缓存在client中(RabbitMQ提供的各种语言的client library)。一旦缓冲区满了，Rabbit将会停止投递新的message到该consumer中直到它发出ack。

假设prefetch值设为10，共有两个consumer。意味着每个consumer每次会从queue中预抓取 10 条消息到本地缓存着等待消费。同时该channel的unacked数变为20。而Rabbit投递的顺序是，先为consumer1投递满10个message，再往consumer2投递10个message。如果这时有新message需要投递，先判断channel的unacked数是否等于20，如果是则不会将消息投递到consumer中，message继续呆在queue中。之后其中consumer对一条消息进行ack，unacked此时等于19，Rabbit就判断哪个consumer的unacked少于10，就投递到哪个consumer中。

总的来说，consumer负责不断处理消息，不断ack，然后只要unacked数少于prefetch * consumer数目，broker就不断将消息投递过去。

## 如何设置

官方提供的java client可以通过channel来设置：
```
channel = connection.createChannel();
channel.basicQos(prefetch);
```


spring-amqp的话可通过配置文件来配置
```
<rabbit:listener-container connection-factory="connectionFactory" concurrency="2" prefetch="3">
    <rabbit:listener ref="listener" queue-names="remoting.queue" />
</rabbit:listener-container>
```

这里需要注意的是，spring-amqp中的prefetch默认值是1。

## 客户端源码剖析

官方Java客户端提供了DefaultConsumer和QueueingConsumer两种类来从queue中获取消息。 其中QueueingConsumer内部维护了一个阻塞队列BlockingQueue，此队列就是用来缓存从queue获取的message。当调用 `channel.basicConsume`后，broker就会不断往consumer投递message，直到prefetch条。

初始化的时候，如果不指定BlockingQueue的长度，默认值会设为Integer.MAX_VALUE，所以这就解释了文章开头所说的如果不设置Qos的话为什么会有可能导致OOM，因为此时BlockingQueue会不断膨胀，消耗内存。所以设置了prefetch后，建议BlockingQueue的长度(capacity)也初始化为prefetch。

另外需要注意的是，在调用`channel.basicConsume`之后，consumer是通过异步方式来抓取message的，通过debug可以发现BlockingQueue的size是在异步地不断增长直到prefetch。而客户端代码可以通过consumer.nextDelivery()或consumer.nextDelivery(long timeout)方法来获取message，其对应的就是BlockingQueue的take()和poll(long timeout)方法。


再来看看spring-amqp的comsumer，大致也一样。核心类BlockingQueueConsumer

```
public class BlockingQueueConsumer {
    
    private final BlockingQueue<Delivery> queue;

    //some code
    ...

public BlockingQueueConsumer(ConnectionFactory connectionFactory,
            MessagePropertiesConverter messagePropertiesConverter,
            ActiveObjectCounter<BlockingQueueConsumer> activeObjectCounter, AcknowledgeMode acknowledgeMode,
            boolean transactional, int prefetchCount, boolean defaultRequeueRejected,
            Map<String, Object> consumerArgs, boolean exclusive, String... queues) {

        //... some code

        this.queue = new LinkedBlockingQueue<Delivery>(prefetchCount);
    }


```

BlockingQueueConsumer的构造函数清楚说明了每个消费者内部的队列大小就是prefetch的大小。而spring-amqp默认的prefetch是1。

## 吞吐量、延迟

prefetch并不是说设置得越大越好。过大可能导致consumer处理不过来，一直在本地缓存的BlockingQueue里呆太久，这样消息在客户端的延迟就大大增加；而对于多个consumer的情况，则会分配不均匀，导致有些consumer一直在忙，有些则非常空闲。

然而设置的过小，又会令到consumer不能充分工作，因为我们总想它100％的时间都是处于繁忙状态，而这时可能会在处理完一条消息后，BlockingQueue为空，因为新的消息还未来得及到达，所以consumer就处于空闲状态了。

prefetch应该设置多大，具体可参考这篇文章

[Some queuing theory: throughput, latency and bandwidth](https://www.rabbitmq.com/blog/2012/05/11/some-queuing-theory-throughput-latency-and-bandwidth/)

里面详细论述吞吐量与prefetch之间的关系。prefetch的设置与以下几点有关：

1. 客户端服务端之间网络传输时间
2. consumer消耗一条消息所执行的业务逻辑的耗时
3. 网络状况


【完】

如有纰漏，欢迎指出


参考资料：

[RabbitMQ QOS vs. Competing Consumers](https://insidethecpu.com/2014/11/11/rabbitmq-qos-vs-competing-consumers/)

[RabbitMQ消费者的几个参数](https://yuanwhy.com/2016/09/10/rabbitmq-concurrency-prefetch/#)

[rabbitmq——prefetch count](https://my.oschina.net/hncscwc/blog/195560)

[AMQP: acknowledgement and prefetching](http://stackoverflow.com/questions/21652517/amqp-acknowledgement-and-prefetching)


