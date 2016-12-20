title: Redis实现原理之对象与编码
date: 2016-12-17 22:14:56
categories: 缓存
tags: Redis
---

上周看完[Redis设计与实现](https://book.douban.com/subject/25900156/)，过程结合Redis的unstable分支的源码来对照，
基本对Redis的实现原理有了个深入的理解。（书本基于3.0版本，源码unstable分支现已去到4.0 rc2，代码略有不同，但思路总体一致）

最大感受，无论从设计还是源码，Redis都尽量做到简单，其中运用到的原理也通俗易懂，一点也不会觉得晦涩。特别是源码，简洁易读，真正做到clean and clear， 而且作者对于代码的设计组织能力功力深厚。

这篇文章以unstable分支的源码为基准，先从大体上整理Redis的对象类型以及底层编码。

# 对象类型

Redis对象由`redisObject`结构体表示。

- Redis中的每个键值对的键和值都是一个redisObject。

- 共有五种类型的对象：字符串（String）、列表（List）、哈希（Hash）、集合（Set）、有序集合（SortedSet），源码`server.h`如下定义：
```
/* The actual Redis Object */
#define OBJ_STRING 0
#define OBJ_LIST 1 
#define OBJ_SET 2
#define OBJ_ZSET 3
#define OBJ_HASH 4
```

- 每种类型的对象至少都有两种或以上的encoding方式，不同编码
可以在不同的使用场景上优化对象的使用场景。用`TYPE`命令可查看某个键值对的类型

# 对象编码


Redis目前使用的编码方式：

```
/* Objects encoding. Some kind of objects like Strings and Hashes can be
 * internally represented in multiple ways. The 'encoding' field of the object
 * is set to one of this fields for this object. 
 */
#define OBJ_ENCODING_RAW     /* Raw representation */ 简单动态字符串
#define OBJ_ENCODING_INT      /* Encoded as integer */ 整数
#define OBJ_ENCODING_HT       /* Encoded as hash table */ 字典
#define OBJ_ENCODING_ZIPLIST  /* Encoded as ziplist */ 压缩列表
#define OBJ_ENCODING_INTSET   /* Encoded as intset */ 整数集合
#define OBJ_ENCODING_SKIPLIST   /* Encoded as skiplist */ 跳跃表
#define OBJ_ENCODING_EMBSTR  /* Embedded sds string encoding */ embstr编码的简单动态字符串
#define OBJ_ENCODING_QUICKLIST  /* Encoded as linked list of ziplists */ 
```

本质上，Redis就是基于这些数据结构而构造出一个对象存储系统。redisObject结构体有个ptr指针，指向对象的底层实现数据结构，encoding属性记录对象所使用的编码，即该对象使用什么数据结构作为底层实现。


### 字符串

字符串对象的编码可以是 INT、RAW 或 EMBSTR。

字符串对象保存的是整数值并且可以用long表示，那么编码会设置为INT。当字符串值得长度大于39字节使用RAW，小于等于39字节使用EMBSTR。

Redis在3.0引入EMBSTR编码，这是一种专门用于保存短字符串的一种优化编码方式，这种编码和RAW编码都是用sdshdr简单动态字符串结构来表示。RAW编码会调用两次内存分配函数来分别创建redisObject和sdshdr结构，
而EMBSTR只调用一次内存分配函数来分配一块连续的空间保存数据，比起RAW编码的字符串更能节省内存，以及能提升获取数据的速度。

不过要注意！！！ EMBSTR是不可修改的，当对EMBSTR编码的字符串执行任何修改命令，总会先将其转换成RAW编码再进行修改；而INT编码在条件满足的情况下也会被转换成RAW编码。

### 列表

Redis3.0之前的列表对象的编码可以是ziplist或者linkedlist。
当列表对象保存的字符串元素的长度都小于64字节并且保存的元素数量小于512个，使用ziplist编码，可以通过修改配置list-max-ziplist-value和list-max-ziplist-entries来修改这两个条件的上限值、两个条件任意一个不满足时，ziplist会变为linkedlist。

从3.2开始Redis只使用quicklist作为列表的编码，
quicklist是ziplist和双向链表的结合体，quicklist的每个节点都是一个ziplist。可以通过修改list-max-ziplist-size来设置一个quicklist节点上的ziplist的长度，取正值表示通过元素数量来限定ziplist的长度；负数表示按照占用字节数来限定，并且Redis规定只能取-1到-5这五个负值
```
-5: 每个quicklist节点上的ziplist大小不能超过64 Kb。（注：1kb => 1024 bytes）
-4: 每个quicklist节点上的ziplist大小不能超过32 Kb。
-3: 每个quicklist节点上的ziplist大小不能超过16 Kb。
-2: 每个quicklist节点上的ziplist大小不能超过8 Kb。（默认值）
-1: 每个quicklist节点上的ziplist大小不能超过4 Kb。
```

另外配置参数list-compress-depth表示一个quicklist两端不被压缩的节点个数
```
0: 表示都不压缩。默认值。
1: 表示quicklist两端各有1个节点不压缩，中间的节点压缩。
2: 表示quicklist两端各有2个节点不压缩，中间的节点压缩。
3: 表示quicklist两端各有3个节点不压缩，中间的节点压缩。
依此类推…
```
这里采用的是一种叫LZF的无损压缩算法

### 哈希

哈希对象的编码可以是ziplist或者hashtable。

使用ziplist 编码时，保存同一键值对的两个节点总是紧挨在一起，键节点在前，值节点在后

同时满足以下两个条件将使用ziplist编码：

1. 所有键和值的字符串长度小于64字节；
2. 键值对的数量小于512个。

不能满足这两个条件的都需要使用hashtable编码。以上两个上限值可以通过hash-max-ziplist-value和hash-max-ziplist-entries来修改 

### 集合

集合对象的编码可以是intset或者hashtable。

当满足以下两个条件时使用intset编码：

1. 所有元素都是整数值；
2. 元素数量不超过512个。

可以修改set-max-intset-entries设置元素数量的上限。使用hashtable编码时，字典的每一个键都是字符串对象，每个字符串对象包含一个集合元素，字典的值全部设置为null。

### 有序集合

有序集合对象的编码可以是ziplist或者skiplist。同时满足以下条件时使用ziplist编码：

1. 元素数量小于128个；
2. 所有member的长度都小于64字节，

以上两个条件的上限值可通过zset-max-ziplist-entries和zset-max-ziplist-value来修改。

ziplist编码的有序集合使用紧挨在一起的压缩列表节点来保存，第一个节点保存member，第二个保存score。ziplist内的集合元素按score从小到大排序，score较小的排在表头位置。

skiplist编码的有序集合底层是一个命名为`zset`的结构体，而一个zset结构同时包含一个字典和一个跳跃表。跳跃表按score从小到大保存所有集合元素。
而字典则保存着从member到score的映射，这样就可以用O(1)的复杂度来查找member对应的score值。

虽然同时使用两种结构，但它们会通过指针来共享相同元素的member和score，因此不会浪费额外的内存。


参考：
[Redis设计与实现](https://book.douban.com/subject/25900156/)
[New encoding for string: embedded SDS. #543](https://github.com/antirez/redis/issues/543)
[Redis内部数据结构详解(5)——quicklist](http://zhangtielei.com/posts/blog-redis-quicklist.html)
[Redis Quicklist - From a More Civilized Age](https://matt.sh/redis-quicklist)