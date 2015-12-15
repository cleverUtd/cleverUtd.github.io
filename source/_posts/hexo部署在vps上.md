title: hexo部署在vps上
date: 2015-12-14 21:11:37
tags: hexo
categories: hexo
---


之前已经成功把hexo托管在了github上，并且可以访问。不过由于本身已经有个linode的vps，所以还是决定把hexo部署在自己的服务器上。

部署过程其实也很简单，因为其实只要把生成的静态文件部署上去即可，完全不涉及后台的交互。所以我在服务器上利用nginx，配置指向存放博客文章的文件夹就搞掂了。

首先我在服务器上的用户目录下先新建一个文件夹blog。
然后就配置nginx,在nginx.conf里加上这么一段：

```
server {
        listen   80;
        server_name  zclau.com;

        proxy_set_header Host $http_host;
        proxy_set_header X-real-ip $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        location / {
            root /home/zclau/blog;
            #index index.html
        }
    }
```

这样当访问zclau.com时，请求都会转发到我的博客根目录/home/zclau/blog 这个文件夹下
然后就可以看到我的博客的首页了。
