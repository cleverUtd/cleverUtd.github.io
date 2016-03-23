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

平时经常都会用到SimpleDateFormat来对日期字符串进行解析和格式化。而且一般都是创建一个Util工具类，然后定义一个静态的SimpleDateFormat实例变量。需要格式化时就直接使用这个变量进行操作。

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

# 性能对比

分别测试了一下上面三种方案，每种方案分别开了10000线程去进行时间格式化，记录下消耗的时间。测试代码如下：

```java
public class Test {

    private final static SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");

    /**
     * Option 1: Create local instances when required
     */
    public static Date parse1(String dateStr) {
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
        try {
            return sdf.parse(dateStr);
        } catch (ParseException e) {
            e.printStackTrace();
        }
        return null;
    }

    /**
     * Option 2: Create an instance of SimpleDateFormat as a class variable but synchronize access to it.
     */
    public static Date parse2(String dateStr) {
        synchronized (sdf) {
            try {
                return sdf.parse(dateStr);
            } catch (ParseException e) {
                e.printStackTrace();
            }
        }
        return null;
    }

    /**
     * Option 3: Create a ThreadLocal to store a different instance of SimpleDateFormat for each thread.
     */
    private static ThreadLocal<SimpleDateFormat> tl = new ThreadLocal<SimpleDateFormat>();

    public static Date parse3(String dateStr) {
        SimpleDateFormat sdf = tl.get();
        if (sdf == null) {
            sdf = new SimpleDateFormat("yyyy-MM-hh");
            tl.set(sdf);
        }
        try {
            return sdf.parse(dateStr);
        } catch (ParseException e) {
            e.printStackTrace();
        }
        return null;
    }

    private static class Task implements Callable<Date> {
        public Date call() throws Exception {
            return parse1("2016-03-21 12:00:00");
        }
    }

    public static void main(String[] args) {
        ExecutorService executorService = Executors.newFixedThreadPool(50);
        List<Future<Date>> resultList = new ArrayList<Future<Date>>();

        long s = System.currentTimeMillis();
        //创建10000个任务并执行
        for (int i = 0; i < 10000; i++) {
            //使用ExecutorService执行Callable类型的任务，并将结果保存在future变量中
            Future<Date> future = executorService.submit(new Task());
            //将任务执行结果存储到List中
            resultList.add(future);
        }

        //遍历任务的结果
        for (Future<Date> fs : resultList) {
            try {
                while (!fs.isDone())
                    ;//Future返回如果没有完成，则一直循环等待，直到Future返回完成
                System.out.println(fs.get().getTime());     //打印各个线程（任务）执行的结果
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (ExecutionException e) {
                e.printStackTrace();
            } finally {
                //启动一次顺序关闭，执行以前提交的任务，但不接受新任务
                executorService.shutdown();
            }
        }
        long e = System.currentTimeMillis();

        System.out.println("time elapse: " + (e - s));
    }
}
```

对于每种方案，我各执行了12次，然后去掉一个最高消耗，一个最低消耗，剩下的取平均值。测试结果如下：

    方案1： 平均 410ms  

    方案2： 平均 217ms 

    方案3： 平均 300ms 


从结果看出，方案1性能最差，因为每次都需要new一个format实例。不推荐使用

方案2虽然看起来最优，但线程越来越多时，因为使用了同步块，当一个线程调用format的方法时，其余线程就会阻塞，性能会优一定影响。

方案3，每个线程维护一个format实例，50个线程就有50个实例，对内存占用的消耗会比方案2要大，当影响不会太大，网上说法是：
对性能要求比较高的情况下，一般推荐使用这种方法

综上所述，方案2和方案3都可以，至于具体使用哪一种，具体情况而定





