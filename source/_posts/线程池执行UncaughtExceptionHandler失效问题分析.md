title: 线程池执行UncaughtExceptionHandler失效问题分析
date: 2018-01-26 00:51:56
categories: Java
tags: 多线程
---

# 场景
我们知道可以对一个Thread对象设置UncaughtExceptionHandler来进行自定义的未捕捉异常处理。具体可参考上一篇文章[Thread自定义异常处理](https://www.jianshu.com/p/65fb5d5198e2)

但是，如果交由线程池来执行的话，

```
public static void main(String[] args) {
        Thread task = new Thread(() -> {
            System.out.println("Before...");
            System.out.println(10 / 0);
            System.out.println("After...");
        });


        task.setName("Thread-demo");
        task.setUncaughtExceptionHandler((t1, e) -> {
            System.out.println("自定义异常: " + t1);
            System.out.println(e);
        });


        ExecutorService exec = Executors.newCachedThreadPool();
        exec.execute(task);
        exec.shutdown();
    }
```

从代码可以看到，线程task设置了UncaughtExceptionHandler，并交给线程池来执行，结果：
![image.png](http://upload-images.jianshu.io/upload_images/8923118-057f20be970597f4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


可以看到，结果并不像我们设想的那样，居然没有走我们自己定义的异常处理的方法。

# 原因
为什么UncaughtExceptionHandler会失效呢，冷静下来仔细回想一下。从上一篇文章的分析中，我们知道只有为线程设置了UncaughtExceptionHandler，该线程在发生异常时，才会执行对应的uncaughtException方法。

如此说来，提交给线程池执行的时候，有可能实际运行task的线程并不是task线程本身（这可能有点拗口）。如果不是task线程本身，又是谁在执行task呢？于是决定对两种方式进行debug，

1、 线程池执行
![image.png](http://upload-images.jianshu.io/upload_images/8923118-be6957df6dcbe0f7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

很明显，当前运行task的是线程池创建的线程"pool-1-thread-1"，而我们只是为线程"Thread-demo"设置了uncaughtExceptionHandler，所以就解释了为什么没有走自定义的处理了。

2、单线程执行
把上面的例子改为task.start()执行，再debug
![image.png](http://upload-images.jianshu.io/upload_images/8923118-2b2663e7710812db.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

可以看到，这一次就是task线程本身也就是"Thread-demo"在执行了，而uncaughtExceptionHandler属性也就不为null。

# 结论
1、如果让线程池执行的同时，也能走自定义uncaughtExceptionHandler，可以在task的开头加上
```
  Thread task = new Thread(() -> {
    Thread.currentThread(). setUncaughtExceptionHandler((t1, e) -> {
            System.out.println("自定义异常: " + t1);
            System.out.println(e);
        });

            System.out.println("Before...");
            System.out.println(10 / 0);
            System.out.println("After...");
        });
```
