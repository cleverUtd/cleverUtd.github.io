title: Jmeter分布式压测
date: 2017-12-08 14:43:43
categories: 性能测试
tags: Jmeter
---

> 进行性能测试时，由于单台机器模拟并发用户数量有限，希望用多台负载机进行负载模拟。我们可以在多台机器上分别部署Jmeter，然后用其中一台做master，控制其他slave实例产生负载。

# step one
部署节点：假设我部署了三台，分别10.199.206.76、10.199.147.249、10.199.205.113
首先确保所有节点：
运行相同版本的Jmeter
运行相同版本的jdk
如果需要用到额外的数据文件，例如我的例子需要用到自定义Java Sampler以及外部properties，每个实例需要各来一份。
master还需要保存一份xxx.jmx测试脚本

如何编写自定义Java Sampler可参看 

[Jmeter使用自定义Java代码压测](http://www.jianshu.com/p/f18b69c68459)

# step two （optional）
配置节点：
这里我选择10.199.206.76做master，10.199.147.249、10.199.205.113作为slave
在master的$JMETER_HOME/bin/jmeter.properties的 remote_hosts属性后配置
![image.png](http://upload-images.jianshu.io/upload_images/8923118-676cce21bd7aa0ef.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#step three
启动slave
![image.png](http://upload-images.jianshu.io/upload_images/8923118-66db6dbcecbee800.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

然后检查一下控制台输出：
![image.png](http://upload-images.jianshu.io/upload_images/8923118-ffc8094fd02629f8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

检查日志，默认会在当前目录写日志
![image.png](http://upload-images.jianshu.io/upload_images/8923118-097cb5e688f46bc1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

有以上输出，没有报错，证明slave启动成功


# step four
启动master进行压测，有两种启动方式
![image.png](http://upload-images.jianshu.io/upload_images/8923118-33250028bec43497.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

或

![image.png](http://upload-images.jianshu.io/upload_images/8923118-6ad1757cdba3b445.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

注意：如果step two 没有配置 remote_hosts，就必须用第一条命令，通过-R 指定slave

然后master就会发送指令给slave执行实际的压测，然后会等待接收slave压测的结果
![image.png](http://upload-images.jianshu.io/upload_images/8923118-68bffc4c5f7cd527.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



# 结果解读
46303 in 00:00:15 = 3134.7/s 表示 在15秒内发送46303条请求，平均每秒处理3134条
Avg：504 表示平均响应时间 504ms
Min：3  表示最小响应时间3ms
Max：14524 表示最长响应时间14524ms



# 参考
[http://jmeter.apache.org/usermanual/remote-test.html](http://jmeter.apache.org/usermanual/remote-test.html)

[https://jmeter.apache.org/usermanual/jmeter_distributed_testing_step_by_step.pdf](https://jmeter.apache.org/usermanual/jmeter_distributed_testing_step_by_step.pdf)



