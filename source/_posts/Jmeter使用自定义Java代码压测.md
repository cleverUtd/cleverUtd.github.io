title: Jmeter使用自定义Java代码压测
date: 2017-11-30 11:27:13
categories: 性能测试
tags: Jmeter
---

Jmeter有几种Sampler，如果想用自定义Java代码来进行压测，就要使用Java Sampler。

那么如何编写Java Sampler，并引入到jmeter进行压测呢？很简单

# step one

首先需要引入依赖
```java
<dependency>
    <groupId>org.apache.jmeter</groupId>
    <artifactId>ApacheJMeter_java</artifactId>
    <version>3.3</version>
    <scope>provided</scope>
</dependency>
```
>这里只是编译时需要用到，实际运行时代码会放在 ${JMETER_HOME}/lib/ext 下，${JMETER_HOME}/lib 下已经有对应依赖了，所以 这里 scope设置为provided即可。

# step two

然后就可以编写测试代码了
```java
public class SdkTest extends AbstractJavaSamplerClient implements Serializable {

    private static Logger logger = LoggerFactory.getLogger(SdkTest.class);

    private static final ConfigCenter configCenter = ConfigCenterFactory.getConfigCenter();

    /**
     * 自定义java方法入参的, 设置可用参数及默认值
     * @return
     */
    @Override
    public Arguments getDefaultParameters() {
        Arguments params = new Arguments();
        params.addArgument("name", "");
        params.addArgument("tag", "");

        return params;
    }

    /**
     * 每个线程测试前执行一次，做一些初始化工作；
     * @param context
     */
    @Override
    public void setupTest(JavaSamplerContext context) {
       super.setupTest(context);
    }


    /**
     * 开始测试，从args参数可以获得参数值；
     * @param args
     * @return
     */
    @Override
    public SampleResult runTest(JavaSamplerContext args) {
        String name = args.getParameter("name");
        String tag = args.getParameter("tag");

        SampleResult result = new SampleResult();

        try {
            result.sampleStart();

            
            //这里就是自定义压测的代码
            .........
            ..........
            ..........
            
            //请求成功，设置测试结果为成功
            result.setSuccessful(true);
        } catch (Exception e) {
            result.setSuccessful(false);
            e.printStackTrace();
        } finally {
            result.sampleEnd();
        }
        return result;
    }

    @Override
    public void teardownTest(JavaSamplerContext context) {
        super.teardownTest(context);
    }
}
```

> 需要注意：Sampler类需要扩展JMeter的类org.apache.jmeter.protocol.java.sampler.AbstractJavaSamplerClient 或 实现 org.apache.jmeter.protocol.java.sampler.JavaSamplerClient接口

# step three
编写完成后，通过 mvn package 打成一个jar包，为了方便，我这里打成的是一个fat包，然后讲其放进 $JMETER_HOME/lib/ext目录下

# step four
打开Jmeter，创建一个Java Request
![image.png](http://upload-images.jianshu.io/upload_images/8923118-176d4d6732d414c5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

然后就能看到刚才编写的Sampler类了
![image.png](http://upload-images.jianshu.io/upload_images/8923118-6c5514d3ee932347.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

红色框处可以定义测试的输入，刚才上面的代码例子中的runTest方法中，就可用通过JavaSamplerContext来获取这些输入
 
然后就可以开心地进行压测了

### 坑
1、如果Sampler代码需要获取外部配置的话，例如需要配置zk server、host等配置，而这些配置是在外部properties中的，需要在启动jmeter的时候加上
```
sh jmeter.sh -Dcom.vipshop.mobile.serconfig=./configcenter.properties
```
