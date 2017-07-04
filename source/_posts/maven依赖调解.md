title: maven依赖调解
date: 2017-07-04 21:35:10
categories:
- Java
tags:
- Maven
---


项目有以下依赖：

```
<dependency>
    <groupId>com.vips.components</groupId>
    <artifactId>vips-common-cache</artifactId>
    <version>2.0</version>
</dependency>
<dependency>
    <groupId>org.apache.poi</groupId>
    <artifactId>poi</artifactId>
    <version>3.9</version>
</dependency>
```

其中

vips-common-cache ---> vip-common-util ---> commons-codec(1.6)

poi ---> commons-codec(1.5)

使用 mvn dependency:tree 分析依赖后，发现maven实际使用的是 poi下的commons-codec(1.5)

![](http://7xp2k4.com1.z0.glb.clouddn.com/5FB88141-2E41-47A3-B09C-AD6986A6A56E.png)



再来看以下情形：

```
<dependency>
    <groupId>org.apache.httpcomponents</groupId>
    <artifactId>httpclient</artifactId>
    <version>4.4.1</version>
</dependency>
<dependency>
    <groupId>org.apache.poi</groupId>
    <artifactId>poi</artifactId>
    <version>3.9</version>
</dependency>
```


httpclient ---> commons-codec(1.9)

poi ---> commons-codec(1.5)



分析依赖后发现，maven选择了commons-codec(1.9)

![](http://7xp2k4.com1.z0.glb.clouddn.com/WX20170620-102526.png)

## 结论：

maven遇到依赖冲突后，主要两种原则解决：

1.路径优先原则：如第一个例子，

vips-common-cache ---> vip-common-util ---> commons-codec(1.6)

poi ---> commons-codec(1.5)

commons-codec(1.6)路径深度是3， commons-codec(1.5)是2，所以maven选择较短路径的那个

2.声明优先原则：如第二个例子，当冲突依赖所处的路径相同，声明在前的会被引用