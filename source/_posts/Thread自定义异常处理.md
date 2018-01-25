title: Thread自定义异常处理
date: 2018-01-25 16:01:48
categories: Java
tags: 多线程
---

# 背景
先来看一个例子
```
 Thread t = new Thread(() -> {
            System.out.println("Before...");
            System.out.println(10 / 0);
            System.out.println("After...");
        });
  t.start();
```
这段代码运行结果是会抛出一个未捕获的异常
![image.png](http://upload-images.jianshu.io/upload_images/8923118-5357159889618f98.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


实际来说，这样是很危险的，因为当线程遇到这种未捕获的异常时，就会立即退出，不会再继续执行之后的代码，这样就无法回收一些系统资源，或者没有关闭当前的连接等等。。。

# 自定义异常处理
我们可以为Thread设定`UncaughtExceptionHandler`,在遇到异常中断时，交由它来处理

```
 Thread t = new Thread(() -> {
            System.out.println("Before...");
            System.out.println(10 / 0);
            System.out.println("After...");
        });

        t.setUncaughtExceptionHandler((t1, e) -> {
            System.out.println("Exception: " + t1);
            System.out.println(e);
        });

t.start();
```

## UncaughtExceptionHandler
![image.png](http://upload-images.jianshu.io/upload_images/8923118-bd763bec2cf92bc3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

UncaughtExceptionHandler在Thread类下定义的一个接口，里面只有一个方法uncaughtException，当一个Thread因为异常而终止时，JVM会触发调用dispatchUncaughtException方法，
![image.png](http://upload-images.jianshu.io/upload_images/8923118-ea01aa16f5c221b2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

此方法会调用getUncaughtExceptionHandler去找对应的handler
![image.png](http://upload-images.jianshu.io/upload_images/8923118-db9a27d09e314dad.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果我们没有自定义UncaughtExceptionHandler的话，就会由当前线程的ThreadGroup对象来处理。
找到handler后，把当前Thread对象以及异常Throwable对象作为参数，传入uncaughtException方法，由该方法来处理这次异常。

文章开头例子的运行结果，就是由ThreadGroup的uncaughtException来输出那一堆的异常栈信息。


