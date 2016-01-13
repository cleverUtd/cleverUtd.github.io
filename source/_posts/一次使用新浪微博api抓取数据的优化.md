title: 一次使用新浪微博api抓取数据的优化
date: 2016-01-05 17:23:25
categories: 
- 代码优化
- Java
tags: 
- 代码优化
- 多线程
---

# 场景

调用新浪微博 根据微博ID返回某条微博的表态列表 接口爬取点赞列表，并将每个点赞用户保存进db

[api文档](http://open.weibo.com/wiki/2/attitudes/show)

# 实现流程

1. 爬取点赞列表
2. 爬取回来的json数据，解析出其中的attitudes数组，如果数组长度大于0，跳去步骤3；否则跳去步骤6
3. 遍历数组，获取对应的user字段(即点赞用户的信息)，构造成User的pojo，并添加进一个User的list里
4. 批量保存 user list 
5. 返回步骤1，爬取下一页数据
6. 退出方法

# 通用版

核心代码： 

```java
    public void fetchAttitudeList(String id, String accessToken, int page, int count) {
        Attitudes attitudes = new Attitudes();
        JSONObject jsonObject;
        JSONObject attitudeJsonObject;
        while (true) {
            try {
                // 调用api获取点赞列表
                jsonObject = attitudes.getAttitudes(accessToken, id, page, count);
                JSONArray jsonArray = jsonObject.getJSONArray("attitudes");
                if (jsonArray.length() > 0) {
                    List<User> users = new ArrayList<>();
                    List<AttitudesMapping> attitudesMappings = new ArrayList<>();
                    for (int i = 0; i < jsonArray.length(); i++) {
                        attitudeJsonObject = jsonArray.getJSONObject(i);
                        if (attitudeJsonObject.has("user")) {
                            // 构造 wbUser
                            User user = new User(attitudeJsonObject.getJSONObject("user"));
                            users.add(user);
                        }
                    }
                    dataService.saveWbUsers(users);//批量保存进db
                    users = null;
                    attitudesMappings = null;
                } else {
                    break;
                }
                page++;
            } catch (Exception e) {
                e.printStackTrace();
            } 
        } 
    }
```

第一版的代码是最容易理解并且实现起来最简单，但是并不通用。因为所有事情都是在一条线程完成，这种执行的步骤是线性且阻塞的。

如果在数据量较少的情况下，使用这种做法倒没有什么问题。但是我这次要爬的这条[微博](http://weibo.com/2082990561/D8SBU9K2z)，有11w+的赞。如果还是用这种做法的话，问题就显现出来了：**太慢，效率太低了**。 总共爬了560多页，全部完成后大概花了一个半小时，实在接受不了。

必须改善优化一下，于是就决定引入线程去处理，尽可能使CPU都得到充分的利用。于是就有了第二个版本的代码

# 线程版

对于线程的使用，交给jdk的Executor框架来控制处理。

这里的线程版本，开始想了两种方案

1. 上面实现流程的 步骤1至步骤4都放在处理线程中。这样主线程只负责页数的控制，然后处理线程负责爬取主线程提供过来的某一页的数据并保存
2. 步骤1,2 在主线程， 步骤3,4在处理线程。这样就是主线程负责爬取每一页的数据，然后数据解析以及保存交给处理线程。


对于方案1，难点在于，主线程不知道数据总共有多少页，因此不知道何时才能结束。这就需要主线程和处理线程之间的通信或者说是合作，才能控制好整个流程。

相比之下，方法2就不存在这个问题了，处理起来简单一些。所以最后我采取了方法2的做法。

核心代码：

```java
    public void fetchAttitudeListAsynProcess(String id, String accessToken, int page, int count) {
        Attitudes attitudes = new Attitudes();
        JSONObject jsonObject;
        //定义一个有10个线程的线程池
        ExecutorService executor = Executors.newFixedThreadPool(10);
        while (true) {
            try {
                // 调用api获取点赞列表
                jsonObject = attitudes.getAttitudes(accessToken, id, page, count);
                JSONArray jsonArray = jsonObject.getJSONArray("attitudes");
                if (jsonArray.length() > 0) {
                    //定义一个runnable
                    RunnableProcessData runnableProcessData = new RunnableProcessData(id, jsonObject, page);
                    //把数据处理的过程交给线程池异步处理
                    executor.execute(runnableProcessData);
                } else {
                    break;
                }
                page++;
            } catch (WeiboException e) {
                e.printStackTrace();
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
    }

    public class RunnableProcessData implements Runnable {
        private String id;
        private JSONObject jsonObject;
        private int page;

        public RunnableProcessData(String id, JSONObject jsonObject, int page){
            this.id = id;
            this.jsonObject = jsonObject;
            this.page = page;
        }

        @Override public void run() {
            JSONArray jsonArray;
            try {
                jsonArray = jsonObject.getJSONArray("attitudes");
                JSONObject attitudeJsonObject;
                List<User> users = new ArrayList<>();
                List<AttitudesMapping> attitudesMappings = new ArrayList<>();
                for (int i = 0; i < jsonArray.length(); i++) {
                    attitudeJsonObject = jsonArray.getJSONObject(i);
                    if (attitudeJsonObject.has("user")) {
                        // 构造 wbUser
                        User user = new User(attitudeJsonObject.getJSONObject("user"));
                        users.add(user);
                    }
                }
                dataService.saveWbUsers(users);
            } catch (JSONException e) {
                e.printStackTrace();
            } catch (WeiboException e) {
                e.printStackTrace();
            } catch (ParseException e) {
                e.printStackTrace();
            }
        }
    }
```

换成了方案2之后，时间快了好几倍，由于之前没有记录下具体的耗时，之前11w+的数据大概是90mins完成的，现在只需大概20mins左右就搞掂了，快了将近75%。

再选取一条[微博](http://weibo.com/1563926367/D6ypd9KJw)测试,结果两种方法的耗时输出分别是：

方案1： ===> 129803。 方案2： ===> 35306

快了 **72%**， 用线程的优势体现的淋漓尽致

# 后续

其实对于上述两种线程池的解决方案，如果要爬取的页数事先已经确定好(例如我只要爬前10页的数据)，这样方案1就不需要和子线程进行通信，只需要在主线程中的循环控制设置好条件  `while(page<=10)`,然后每次循环体的执行都交给子线程处理即可。

经过测试两种方案的耗时分别是：

方案1：===> 3778
方案2：===> 12684

方案1比方案2快了 **70%**

# 总结

1. 对于耗时长且不需要等待有结果返回才能进行下一步的任务，考虑用线程，尽可能利用CPU资源
2. 对于线程的使用，尽量用jdk的Executor框架，里面提供各种丰富线程池实现可供调用
3. 以上代码仅仅是示例代码，如果要用在生产上还需要有好多地方细究下去，例如应该使用哪种Executor的具体实现好；线程池大小应该设置成多少才会达到效率最高；executor应该交给spring管理等等

完.
