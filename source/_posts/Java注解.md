title: Java注解
date: 2016-04-03 21:35:41
categories: Java
tags: core Java
---

# 概念

注解就是代码的元数据，而元数据是一种描述数据的数据。

# 系统注解

分为标准注解和元注解

## 1. 标准注解

1. @Override:保证编译时候Override函数的声明正确性

2. @Deprecated:对不应该在使用的方法添加注释

3. @SuppressWarnings: 关闭特定的警告信息

<!-- more -->

## 2. 元注解

负责注解其他注解

@Retention:注解使用级别

- SOURCE:注释将被编译器丢掉
- CLASS: 注释在class文件中可用，但会被JVM丢弃
- RUNTIME: JVM会在运行时保留注释，因此可以通过反射机制读取注释的信息

@Target: 表示该注解可以用于什么地方

- CONSTRUCTOR: 构造器的声明
- FIELD: 域声明(包括enum实例)
- LOCAL_VARIABLE: 局部变量声明
- METHOD:方法声明
- PACKAGE:包声明
- PARAMETER：参数声明
- TYPE:类、接口(包括注解类型)或enum声明

@Documented: 将注释包含在JavaDoc中

@Inherited:允许子类继承父类中的注解

## 注解元素数据类型

- 所有基本类型(int,float,boolean等)
- String
- enum
- Annotation
- 以上类型的数组

# 自定义注解

创建一个新的注解类型名为 `CustomAnnotationClass

```
 public @interface CustomAnnotation
```

定义属性，定义保留策略和目标

```java
 @Retention(RetentionPolicy.RUNTIME)
 @Target(ElementType.TYPE)
 public @interface CustomAnnotation {

}
```

定义注解成员

```java
 @Retention(RetentionPolicy.RUNTIME)
 @Target(ElementType.TYPE)
 public @interface CustomAnnotation {

    String author() default "zclau";

    public String date();

    public String description();

}
```

使用注解

```java
@CustomAnnotation(date = "2016-04-03", description = "hello world")
public class AnnotatedClass {
}
```

# 获取注解

Java 反射API提供了很多方法来在运行时从类、方法或者其它元素获取注解

* getAnnotations():返回该元素的所有注解，包括没有显示定义该元素上的注解
* isAnnotationPresent(annotation):检查传入的注解是否存在于当前元素
* getAnnotation(class):按照传入的参数获取指定类型的注解，返回null说明当前元素不带有此注解

从一个类中获取所有的存在的注解

```java
@CustomAnnotation(date = "2016-04-03", description = "hello world")
public class AnnotatedClass {

    public static void main(String[] args) {

        Class<AnnotatedClass> object = AnnotatedClass.class;
        //从AnnotatedClass类中获取所有的注解
        Annotation[] annotations = object.getAnnotations();
        for(Annotation annotation : annotations) {
            System.out.println(annotation);
        }

        if(object.isAnnotationPresent(CustomAnnotation.class)) {
            Annotation annotation = object.getAnnotation(CustomAnnotation.class);
            System.out.println(annotation);
        }
    }
}

```
