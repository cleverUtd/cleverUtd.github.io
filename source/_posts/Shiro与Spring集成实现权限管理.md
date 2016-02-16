title: Shiro与Spring集成实现权限管理
date: 2016-02-16 18:25:17
categories: Web开发
tags: Shiro
---

# 1. shiro核心概念

## Subject

    大多数情况下,可以简单理解成"当前用户"的概念,在代码任何地方都可以获取,获取后能够进行登录,登出,授权检查等操作

## SecurityManager

    Subject代表了当前用户的安全操作,SecurityManager管理所有用户的安全操作。它是Shiro框架的核心

## Realms

    相当于数据源。配置Shiro时，必须至少指定一个Realm。执行认证和授权时，shiro会从realms获取认证数据


关于shiro的教程这里就不详述了，可参考：

[apache-shiro-1.2.x-reference](https://waylau.gitbooks.io/apache-shiro-1-2-x-reference/content/index.html)

[跟我学Shiro](http://jinnianshilongnian.iteye.com/blog/2049092)

[让Apache Shiro保护你的应用](http://www.infoq.com/cn/articles/apache-shiro)

<!-- more -->

# 2. maven配置依赖

```java
    <dependency>
            <groupId>org.apache.shiro</groupId>
            <artifactId>shiro-core</artifactId>
            <version>${shiro.version}</version>
    </dependency>
    <dependency>
            <groupId>org.apache.shiro</groupId>
            <artifactId>shiro-web</artifactId>
            <version>${shiro.version}</version>
    </dependency>
    <!-- 如果要与spring集成，需要添加此依赖 -->
    <dependency>
            <groupId>org.apache.shiro</groupId>
            <artifactId>shiro-spring</artifactId>
            <version>${shiro.version}</version>
    </dependency>
```

${shiro.version}请自行替换成当前的最新版本

# 3. 整合spring

## 3.1 web.xml

增加filter和filter-mapping

```
     <filter>
        <filter-name>shiroFilter</filter-name>
        <filter-class>org.springframework.web.filter.DelegatingFilterProxy</filter-class>
        <init-param>
            <param-name>targetFilterLifecycle</param-name>
            <param-value>true</param-value>
        </init-param>
    </filter>

    <filter-mapping>
        <filter-name>shiroFilter</filter-name>
        <url-pattern>/*</url-pattern>
    </filter-mapping>
```

filter-name对应spring配置中定义的名字为“shiroFilter”的bean

## 3.2 spring配置

新建spring-shiro.xml
```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:util="http://www.springframework.org/schema/util"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://www.springframework.org/schema/util http://www.springframework.org/schema/util/spring-util.xsd">

       <!-- 定义Realm -->
       <bean id="myRealm" class="com.uniweibov2.shiro.realm.MyRealm" />
       <!-- 自定义filter -->
       <bean id="roles" class="com.uniweibov2.shiro.filter.MyRoleFilter" />
       <bean id="perms" class="com.uniweibov2.shiro.filter.MyURLPermissionFilter" />

       <bean id="securityManager" class="org.apache.shiro.web.mgt.DefaultWebSecurityManager">
              <property name="realm" ref="myRealm"/>
       </bean>
  
       <bean id="shiroFilter" class="org.apache.shiro.spring.web.ShiroFilterFactoryBean">
              <property name="securityManager" ref="securityManager"/>
              <property name="loginUrl" value="/user/login" />
              <property name="unauthorizedUrl" value="/unauth"  />
              <property name="filters">
                    <map>
                            <entry key="roles" value-ref="roles" />
                            <entry key="perms" value-ref="perms" />
                     </map>
              </property>
              <!-- 过滤链定义 -->  
              <property name="filterChainDefinitions">
                     <value>
                            /user/login = anon <!--anon:anonymous, 匿名的, 不需要权限 -->
                            /user/logout = logout
                            /my/customer/** = roles["user"]   <!-- 需要名称为user的角色权限-->
                           /customer/**=perms 
                     </value>
              </property>
       </bean>

       <!-- Shiro生命周期处理器 -->
       <bean id="lifecycleBeanPostProcessor" class="org.apache.shiro.spring.LifecycleBeanPostProcessor"/>

</beans>
```

filters属性用于自定义过滤器

filterChainDefinitions用于声明url和filter的关系，即哪些URL需要经过哪些filter进行鉴权

shiro也有很多默认的filter，上面的anon和logout使用的就是shiro默认filter。默认的roles和perms filter不满足要求，所以这里使用自定义的实现

配置好spring-shiro.xml，在spring.xml里import即可。

# 4 自定义Realm

新建MyRealm：
```
public class MyRealm extends AuthorizingRealm {

    @Autowired
    private UserRoleService userRoleService;
    @Autowired
    private RoleResourcesService roleResourcesService;
    @Autowired
    private ShiroRedis shiroRedis;

    Logger log = LoggerFactory.getLogger(MyRealm.class);

     /**
     * 获取授权信息
     * 每当需要鉴权时，都会先通过此方法获取用户拥有的权限，并包装成shiro自己封装的AuthorizationInfo对象里面
     */
    @Override
    protected AuthorizationInfo getAuthorizationInfo(PrincipalCollection principals) {
        if (principals == null) {
            return null;
        } else {
            AuthorizationInfo info = null;
            if (log.isTraceEnabled()) {
                log.trace("Retrieving AuthorizationInfo for principals [" + principals + "]");
            }

            info = shiroRedis.getAuthinfo(principals.toString());
            if (info == null) {
                info = this.doGetAuthorizationInfo(principals);
                if (info != null) {
                    if (log.isTraceEnabled()) {
                        log.trace("Caching authorization info for principals: [" + principals + "].");
                    }
                    shiroRedis.putAuthinfo(principals.toString(), JsonUtil.obj2JsonStr(info));
                }
            }
            return info;
        }
    }

    /**
     * 获取授权信息，在这个方法中，从db获取当前登录用户的角色和资源权限信息
     */
    @Override
    protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principalCollection) {
        int userId = Integer.parseInt((String) getAvailablePrincipal(principalCollection));
        List<UserRoles> userRoles = userRoleService.getRoleByUserId(userId);

        //通过用户名从数据库获取权限字符串
        SimpleAuthorizationInfo info = new SimpleAuthorizationInfo();
        //角色权限
        Set<String> roleSet = new HashSet<>();
        //资源权限
        Set<String> resourcesSet = new HashSet<>();

        for (UserRoles userRole : userRoles) {
            roleSet.add(userRole.getRoleName());
            List<RoleResources> resourceList = roleResourcesService.getResourcesByRole(userRole.getRoleId());
            for(RoleResources roleResources : resourceList) {
                resourcesSet.add(roleResources.getUri() + ":" + roleResources.getMethod());
            }
        }
        info.setRoles(roleSet);
        info.setStringPermissions(resourcesSet);
        return info;
    }

    /**
     * 身份认证
     */
    @Override
    protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken token) throws AuthenticationException {
        String userId = (String) token.getPrincipal();
        String password = new String((char[]) token.getCredentials());
        AuthenticationInfo aInfo = new SimpleAuthenticationInfo(userId, password, getName());
        return aInfo;
    }
```

AuthorizingRealm是Shiro负责身份认证的抽象类。需要实现doGetAuthenticationInfo和doGetAuthorizationInfo方法。

一般来说在doGetAuthenticationInfo方法里,实现的是对用户提交过来的用户名/密码 等账号信息,跟数据库进行交互判定登陆是否成功的过程。但是因为我们的系统之前已经有自己的一套认证逻辑，所以在这个方法里就不进行匹配，只是简单的包装成AuthenticationInfo对象并返回。
而在原来的登录认证代码中(UserController的login方法)，在匹配成功后，添加以下代码
```
Subject subject = SecurityUtils.getSubject();
UsernamePasswordToken token = new UsernamePasswordToken(user.getUserId().toString(), user.getPasswd());
//此方法会进入MyRealm的doGetAuthenticationInfo()方法
subject.login(token);
```

getAuthorizationInfo重写父类方法，此方法中，先通过redis查找用户的认证信息，如果没有调用doGetAuthorizationInfo方法从db中获取。
因为shiro默认的缓存只提供ecache实现，所以需要重写getAuthorizationInfo，自定义redis的缓存实现

doGetAuthorizationInfo 的中资源权限我使用URI:method("/user/create:post") 形式作为权限字符串

# 5 权限校验

## 5.1 数据库设计

角色表
```
CREATE TABLE `roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '角色id',
  `name` varchar(32) NOT NULL DEFAULT '' COMMENT '角色名称',
  `detail` varchar(32) NOT NULL DEFAULT '' COMMENT '角色附加描述',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` tinyint(4) NOT NULL DEFAULT '0' COMMENT '删除标识,0.可用，1.已删除不可用',
  PRIMARY KEY (`id`),
  UNIQUE KEY `u_key_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='角色表';
```

用户角色映射
```
CREATE TABLE `user_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `user_id` int(11) NOT NULL DEFAULT '0' COMMENT '用户uid, 对应表users(u_id)',
  `role_id` int(11) NOT NULL DEFAULT '0' COMMENT '角色id, 对应表roles(ro_id)',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` tinyint(4) NOT NULL DEFAULT '0' COMMENT '删除标识,0.可用，1.已删除不可用',
  PRIMARY KEY (`id`),
  UNIQUE KEY `u_key_u_id_ro_id` (`user_id`,`role_id`),
  KEY `u_key_ro_id` (`role_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='用户角色表';
```

资源表(记录系统使用到的URL)
```
CREATE TABLE `resources` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `uri` varchar(64) NOT NULL DEFAULT '' COMMENT '请求相对路径',
  `method` varchar(8) NOT NULL DEFAULT '' COMMENT'请求方法 GET/POST',
  `detail` varchar(32) NOT NULL DEFAULT '' COMMENT 'uri详细描述',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` tinyint(4) NOT NULL DEFAULT '0' COMMENT '删除标识,0.可用，1.已删除不可用',
  PRIMARY KEY (`id`),
  UNIQUE KEY `u_key_uri_method` (`uri`,`method`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='请求相对路径记录表';
```

角色-资源权限映射表
```
CREATE TABLE `role_resources` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '自增id',
  `resource_id` int(11) NOT NULL DEFAULT '0' COMMENT '请求相对路径id',
  `role_id` int(11) NOT NULL DEFAULT '0' COMMENT '角色id',
  `create_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT '创建时间',
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `is_deleted` tinyint(4) NOT NULL DEFAULT '0' COMMENT '删除标识,0.可用，1.已删除不可用',
  PRIMARY KEY (`id`),
  UNIQUE KEY `u_key_role_resource` (`role_id`,`resource_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='角色-资源权限映射表';
```

user和role是多对多关系，角色和资源也是多对多关系


## 5.2 角色校验 

自定义RolesAuthorizationFilter
```
public class MyRoleFilter extends RolesAuthorizationFilter {

    private Logger log = LoggerFactory.getLogger(MyRoleFilter.class);

    @Override
    protected boolean onAccessDenied(ServletRequest request, ServletResponse response) throws IOException {
        HttpServletRequest req = com.uniweibov2.shiro.WebUtils.toHttp(request);
        HttpServletResponse res = com.uniweibov2.shiro.WebUtils.toHttp(response);
        String path = WebUtils.getRequestUri(req);
      //my开头的请求用于页面跳转
        if (path.startsWith("/my")) {
            res.sendError(401);
        } else { //其余是ajax异步请求
            PrintWriter out = response.getWriter();
            out.println("{\"error_info\":\"permission denied.\"}");
            out.flush();
            out.close();
        }
        return false;
    }

    @Override
    public boolean isAccessAllowed(ServletRequest request, ServletResponse response, Object mappedValue) throws IOException {

        final Subject subject = getSubject(request, response);
        HttpServletRequest req = (HttpServletRequest) request;
        //mappedValue的值就是上面spring-shiro.xml 过滤器链定义中roles["user,admin"] 括号里面的值
        final String[] rolesArray = (String[]) mappedValue;
        if (rolesArray == null || rolesArray.length == 0) {
            return true;
        }

        for (String roleName : rolesArray) {
            if (subject.hasRole(roleName)) {  //判断当前用户是否拥有这个角色
                return true;
            }
        }
        return false;
    }
```

MyRoleFilter重写isAccessAllowed和onAccessDenied方法

isAccessAllowed方法用于角色权限检测，因为父类的isAccessAllowed方法中的检测逻辑是必须符合所有mappedValue中的角色，而我们的需求是只有用户属于其中任意一个角色就可以通过了，因此需要自定义实现

onAccessDenied方法实现的是当权限不通过时，应该如何处理

## 5.3 URL权限校验

自定义PermissionsAuthorizationFilter
```
public class MyURLPermissionFilter extends PermissionsAuthorizationFilter{

    private Logger log = LoggerFactory.getLogger(MyURLPermissionFilter.class);

    @Override
    protected boolean onAccessDenied(ServletRequest request, ServletResponse response) throws IOException {
        HttpServletRequest req = WebUtils.toHttp(request);
        HttpServletResponse res = WebUtils.toHttp(response);
        String path = WebUtils.getRequestUri(req);
        if(path.startsWith("/my/")) {
            res.sendError(401);
            return false;
        } else {
            PrintWriter out = response.getWriter();
            out.println("{\"error_info\":\"permission denied.\"}");
            out.flush();
            out.close();
            return false;
        }
    }

    @Override
    public boolean isAccessAllowed(ServletRequest request, ServletResponse response, Object mappedValue) throws IOException {
        Subject subject = this.getSubject(request, response);
        HttpServletRequest req = WebUtils.toHttp(request);
        String path = WebUtils.getRequestUri(req);
        String method = req.getMethod();
        String permission = path + ":" + method;

        if(!subject.isPermitted(permission)) { //与上文MyRealm的getAuthorizationInfo方法返回的AuthorizationInfo中的权限集合匹配
            return false;
        }
        return true;
    }
```


到目前为止，已经完成shiro与spring整合，并且实现了角色和URL的权限管理了。

# 6. 常见问题

## 6.1 关于shiro session

Shiro 中的 Session 不依赖 HTTP 环境。如果将 Shiro 部署在 web 应用程序中，那么这个 Session 就是基于HttpSession 的。在非 web 环境下使用，Shiro 则默认使用 EnterpriseSessionManagment



【完】

参考：

[Spring 整合 Apache Shiro 实现各等级的权限管理](http://blog.aquariuslt.com/2015/10/25/apache-shiro-spring-integration)
