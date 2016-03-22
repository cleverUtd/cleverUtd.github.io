title: Java SimpleDateFormat的线程安全性问题
date: 2016-03-22 23:07:16
categories:
- Java
tags:
- SimpleDateFormat
---

# 问题：

```java
public class Test {
    private static SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");

    private static class Task implements Runnable {

        public void run() {
            try {
                System.out.println(sdf.parse("2016-03-21 12:00:00").getTime());
            } catch (ParseException e) {
                e.printStackTrace();
            }
        }
    }

    public static void main(String[] args) {
        Task task = new Task();

        Thread t1 = new Thread(task);
        t1.start();
        Thread t2 = new Thread(task);
        t2.start();
        Thread t3 = new Thread(task);
        t3.start();
        Thread t4 = new Thread(task);
        t4.start();
        Thread t5 = new Thread(task);
        t5.start();
    }
}
```

平常经常都会用到SimpleDateFormat来对日期字符串进行解析和格式化。而且一般都是创建一个Util工具类，然后定义一个静态的SimpleDateFormat实例变量。需要格式化时就直接使用这个变量进行操作。

在大多数正常的测试情况之下，出来的结果都是没问题的。然而，我最近在看《Java并发编程实践》的过程中才发现这样做并不是线程安全的，当在并发量较高的生产环境中，问题就出现了，会出现各种不同的错误，例如线程被挂死，转换的时间不正确。

下图的输出结果是线程被挂死了：

![](http://7xp2k4.com1.z0.glb.clouddn.com/QQ20160322-1@2x.png)

下图是转换的时间不对：
![](http://7xp2k4.com1.z0.glb.clouddn.com/QQ20160322-0@2x.png)

# 原因

以前之所以忽略这个问题，一来对多线程没有很深入的理解；二是因为从这个类中完全看不出与线程安全有什么关系，因为SimpleDateFormat 实例变量已经是用final 修饰了，就一直以为是状态不变的了。

而在jdk的官方文档里面，也有提到

    " Date formats are not synchronized. It is recommended to create separate format instances for each thread. If multiple threads access a format concurrently, it must be synchronized externally."

就是说。Date format不是同步的，建议每个线程都分别创建format实例变量；或者如果多个线共享一个format的话，必须保持在使用format时是同步的

# 解决方案

## 1. 需要的时候创建局部变量

```java
public Date formatDate(Date d) {
    SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
    return sdf.parse(d);
}
```

## 2. 创建一个共享的SimpleDateFormat实例变量，但是在使用的时候，需要对这个变量进行同步

```java
private SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
public Date formatDate(Date d) {
    synchronized(sdf) {
        return sdf.parse(d);
    }
}
```

## 3. 使用ThreadLocal为每个线程都创建一个线程独享SimpleDateFormat变量

```java
private ThreadLocal<SimpleDateFormat> tl = new ThreadLocal<SimpleDateFormat>();
public Date formatDate(Date d) {
    SimpleDateFormat sdf = tl.get();
    if(sdf == null) {
        sdf = new SimpleDateFormat("yyyy-MM-dd");
        tl.set(sdf);
    }
    return sdf.parse(d);
}
```


