title: Java基础：String使用
date: 2016-12-01 21:15:10
categories: Java
tags: Core Java
---

字符串操作是最常见的操作。在Java中，往往使用String类来进行各种字符串操作。
而对于String这个类，其实隐含不少特性。对此，自己最近梳理了一遍。

# 字符串创建

常用方式主要两种：

```
String a = "123"
```

和

```
String b = new String("123");
```

第一种方式，”123“直接存储在常量池；第二种方式实际创建了两个对象，第一个对象是”123“字符串在常量池中，第二个对象是在java堆中的String对象。

# 不可变

翻看jdk源码，java.lang.String的定义是这样的：

```
public final class String
    implements java.io.Serializable, Comparable<String>, CharSequence {
    /** The value is used for character storage. */
    private final char value[];
    /** Cache the hash code for the string */  
    private int hash; // Default to 0  
    
    ...
    ...

```

以上代码在jdk7，8都是一致的。

String类用final修饰，从java的final关键字语义上看，说明String不可继承。

其次，String的底层其实用了一个final类型的char数组来存储，说明该字段一旦创建后就不能改变。

其中有个很容易引起迷惑的地方，必须要弄清楚：String对象本质是引用，我们所说的不可变是指引用指向的对象内容不可变，并不是引用不可变。而String类中涉及修改的方法（substring、replace、toLowerCase等）都是创建一个新的字符串，并把这个它重新赋给引用。这就说明引用是重新指向了一个新的的字符串，但原来的字符串依旧存在内存里。

虽然说String不可变，但也不是绝对不可变，可以通过反射机制进行修改。然而大多情况不需要也没必要用到反射，这里就不详细讨论了

具体可参考[Java中的String为什么是不可变的？ -- String源码分析](http://blog.csdn.net/zhangjg_blog/article/details/18319521)
里面阐述比较详细了。


# 字符串‘+’操作

以前的文章中很多都说字符串‘+’操作会导致性能低效，要用StringBuilder或StringBuffer。但其实现在的JVM已经优化得足够强大，

例如以下代码
```
public class StringTest{
    public static void main(String[] args) {
        String a = "hello";
        String b = "abc" + "def" + 47 + a;
    }

```
通过 javap -c 反编译出来的字节码如下：

```
public static void main(java.lang.String[]);
    Code:
       0: ldc           #2                  // String hello
       2: astore_1
       3: new           #3                  // class java/lang/StringBuilder
       6: dup
       7: invokespecial #4                  // Method java/lang/StringBuilder."<init>":()V
      10: ldc           #5                  // String abcdef47
      12: invokevirtual #6                  // Method java/lang/StringBuilder.append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      15: aload_1
      16: invokevirtual #6                  // Method java/lang/StringBuilder.append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      19: invokevirtual #7                  // Method java/lang/StringBuilder.toString:()Ljava/lang/String;
      22: astore_2
      23: return
}
```

我们可以看到，字符串的‘+’操作其实在实际执行过程中，就是一个StringBuilder的append操作。


再看这段代码：

```
public class StringTest{
    public static void main(String[] args) {
        String a = "";
        for (int i=0;i<10;i++) {
            a = a + i;
        }
    }
}
```

对应的字节码：

```
public static void main(java.lang.String[]);
    Code:
       0: ldc           #2                  // String
       2: astore_1
       3: iconst_0
       4: istore_2
       5: iload_2
       6: bipush        10
       8: if_icmpge     36
      11: new           #3                  // class java/lang/StringBuilder
      14: dup
      15: invokespecial #4                  // Method java/lang/StringBuilder."<init>":()V
      18: aload_1
      19: invokevirtual #5                  // Method java/lang/StringBuilder.append:(Ljava/lang/String;)Ljava/lang/StringBuilder;
      22: iload_2
      23: invokevirtual #6                  // Method java/lang/StringBuilder.append:(I)Ljava/lang/StringBuilder;
      26: invokevirtual #7                  // Method java/lang/StringBuilder.toString:()Ljava/lang/String;
      29: astore_1
      30: iinc          2, 1
      33: goto          5
      36: return
}
```

对于循环内的字符串拼接，虽然还是转化为StringBuilder，但是情况有点不同，留意8：和 33：之间的代码就是每一次循环所执行的操作，可以看到每一次的循环都创建了一个新的StringBuilder对象。

所以总结来说，对于普通的一次性的‘+’操作，可以放心使用；但循环下的‘+’，因为每一次都要new 一个StringBuilder而导致性能降低，因此还是先自己定义一个StringBuilder，然后每次循环通过append操作来完成

# 字符串常量池

JVM为了提高性能和减少内存开销，在实例化字符串常量的时候进行了一些优化。为了减少在JVM中创建的字符串的数量，字符串类维护了一个字符串池，每当创建字符串常量时，JVM会首先检查字符串常量池。如果字符串已经存在池中，就返回池中的实例引用。如果字符串不在池中，就会实例化一个字符串并放到池中

在JDK6中，字符串常量池在永久代分配内存；而JDK7开始，常量池已经在Java堆上分配内存。

而字符串常量池本质是个固定容量的HashMap。 Java7和8可以通过 -XX:StringTableSize 设置其map size。
在Java6到Java7u40之前-XX:StringTableSize的默认大小是1009；7u40之后扩大到60013。

-XX:+PrintStringTableStatistics 会在程序终止时打印字符串常量池的使用情况


# String.intern

String.intern是把双刃剑，用时需谨慎，切记切记！！！

String.intern()是一个Native方法，底层调用C++的 StringTable::intern 方法。

源码注释：当调用 intern 方法时，如果常量池中已经存在该字符串，则返回池中的字符串；否则将此字符串添加到常量池中，并返回字符串的引用。
在这里jdk6和jdk7表现有点区别：
1. jdk6会直接生成一个新的字符串对象到常量池中，并返回该对象引用
2. jdk7因为常量池不在Perm区，不需要重新生成对象，而是直接存储堆中的引用

关于stirng.intern的更深入分析可看
[深入解析String#intern](http://tech.meituan.com/in_depth_understanding_string_intern.html)
以及
详细可看白衣大神的[String.intern() 祛魅](http://calvin1978.blogcn.com/articles/string-intern.html)


# substring()

jdk6与jdk7中的实现方式不一样。

jdk6调用substring()虽然会创建一个新的字符串对象，但里面的char[] 仍然指向原来的那个，
因此对一个很长很长的字符串进行截取后，可能导致内存泄露。

jdk7中substring()方法在堆中真正的创建了一个新的数组,原字符数组没有被引用后就被GC回收了.因此避免了上述问题.



如有纰漏，敬请指出~


参考：
[String.intern in Java 6, 7 and 8 – string pooling](http://java-performance.info/string-intern-in-java-6-7-8/)
[JDK6和JDK7中的substring()方法](http://www.importnew.com/7418.html)