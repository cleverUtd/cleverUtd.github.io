title: RabbitMQ的Qos prefetch
date: 2016-09-15 18:19:11
categories: 消息队列
tags: RabbitMQ
---

实际使用RabbitMQ过程中，如果不设置QoS，broker会把队列中的消息不断投递到client中所有订阅此queue的consumer中。这时就有可能导致client端的内存暴涨，因为这时所有consumer是在本地缓存所有的message，这样极有可能导致进程OOM或者导致服务器内存不足影响其它进程的正常运行。所以我们需要通过设置Qos的prefetch count来控制consumer的流量。同时设置得当也会提高consumer的吞吐量。

## 消息投递

假设prefetch值设为10，意味着每个consumer每次会从queue中预抓取 10 条消息到本地缓存着等待消费。同时该channel的unacked数变为10。如果这时有message需要投递，先判断channel的unacked数是否等于10，如果是则不会将消息投递到consumer中，message继续呆在queue中。之后consumer对一条消息进行ack，unacked少于10，broker可以继续投递消息给consumer。

总的来说，consumer负责不断处理消息，不断ack，然后只要unacked数少于prefetch，broker就不断将消息投递过去直到unacked等于prefetch。

## 设置prefetch

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

## 客户端源码

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




[RabbitMQ消费者的几个参数](https://yuanwhy.com/2016/09/10/rabbitmq-concurrency-prefetch/#)

[Some queuing theory: throughput, latency and bandwidth](https://www.rabbitmq.com/blog/2012/05/11/some-queuing-theory-throughput-latency-and-bandwidth/)