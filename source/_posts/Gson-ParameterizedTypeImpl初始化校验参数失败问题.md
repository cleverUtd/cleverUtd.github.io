title: Gson ParameterizedTypeImpl初始化校验参数失败问题
date: 2017-12-22 22:32:26
categories: Java
tags: Gson
---

# 问题背景

今天在对某个接口做junit测试时，报如下错误

![image.png](http://upload-images.jianshu.io/upload_images/8923118-c33bef422e7f3680.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

发生错误的本质就是：某个bean在初始化时使用了gson做参数类型映射， 旗下ParameterizedTypeImpl 解析泛型数据时出错，导致创建bean失败，从而导致spring 容器启动失败

而奇怪的是，通过gradle打包运行却是正常的，但跑junit测试却一直报错。

# 分析

从堆栈错误可以看到，是在初始化ParameterizedTypeImpl时，调用checkArgument方法时报错， 这时用的gson版本是2.2.2。找到对应的源码位置
![image.png](http://upload-images.jianshu.io/upload_images/8923118-5b841939f074f386.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

然后再来看看客户端初始化ParameterizedTypeImpl传入的参数：
![image.png](http://upload-images.jianshu.io/upload_images/8923118-72b8836e2f0b8418.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

- ownerType是null
- rawType是ClientService类下的一个静态内部类Response

第一个checkArgument校验，ownerType不为null或者rawType不是内部类的条件明显不满足，所以就是在这里抛的illegalArgumentException。



通过gradle打包方式运行，发现使用的是gson 2.8.0（这里注意一下，我们的系统同时存在2.2.2， 2.6.2以及2.8.0版本的gson，gralde解决版本冲突的策略是选取最新的那个版本），没有抛错，而2.8.0对应ParameterizedTypeImpl初始化的代码
![image.png](http://upload-images.jianshu.io/upload_images/8923118-ec31e8288b975523.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

可以看到2.8.0对应的校验条件发生了变化：
- ownerType不为null 或
- rawType是静态类，或者不是内部类

我们的Response类是静态类，所以通过校验，没有报错。


# 解决办法
- 强制使用gson 2.8.0，具体参考 [Gradle ResolutionStrategy](https://docs.gradle.org/current/dsl/org.gradle.api.artifacts.ResolutionStrategy.html)

# 总结
- ParameterizedTypeImpl初始化从2.3.0版本开始更改了校验参数的方式的，如果你在使用的时候发现出现参数校验异常，并且使用的是2.2.2及之前的版本，可以考虑升级gson版本