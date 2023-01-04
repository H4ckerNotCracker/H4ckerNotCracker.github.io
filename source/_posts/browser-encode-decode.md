---
title: 编码与解码 -- 浏览器做了什么  
date: 2020-01-02 03:00:00
tags:
---

编码与解码 -- 浏览器做了什么        

浏览器是如何解码的
=========

无论是作为开发，还是作为黑客，企图从Web 端注入SQL，或者是XSS 的时候，编码和解码都是一个重要的问题、作为一个浏览器，有URL解析引擎，有HTML解析引擎，还有JS 解析引擎。其执行的先后顺序往往决定了输出的结果。这种多标签语言互相嵌入的，同时又需要客户端服务器交互的技术，正是给了XSS 可趁之机。下面我们要做的，是去了解浏览器到底如何解码，该如何在解码过程中避免漏洞的产生。在此之上，我更愿意揭开整个浏览器的工作流程，了解其本质。

这里有篇神文[How browsers work](http://taligarsiel.com/Projects/howbrowserswork1.htm)， 也是本篇文章的重要参考。

浏览器基本的工作流程
----------

进入主话题之前，先闲扯一些废话，先罗列一下浏览器的主要构成：

1.  用户界面－ 包括地址栏、后退/前进按钮、书签目录等，也就是你所看到的除了用来显示你所请求页面的主窗口之外的其他部分
2.  浏览器引擎－ 用来查询及操作渲染引擎的接口
3.  渲染引擎－ 用来显示请求的内容，例如，如果请求内容为html，它负责解析html及css，并将解析后的结果显示出来
4.  网络－ 用来完成网络调用，例如http请求，它具有平台无关的接口，可以在不同平台上工作
5.  UI 后端－ 用来绘制类似组合选择框及对话框等基本组件，具有不特定于某个平台的通用接口，底层使用操作系统的用户接口
6.  JS解释器－ 用来解释执行JS代码
7.  数据存储－ 属于持久层，浏览器需要在硬盘中保存类似cookie的各种数据，HTML5定义了web database技术，这是一种轻量级完整的客户端存储技术

其组件架构是这样的：  
![](http://7s1s1q.com1.z0.glb.clouddn.com/2016-05-18-14635395450775.jpg)

值得一提的是，对于Chrome 浏览器来说，Chrome 为每个Tab 都分配了各自的渲染引擎，每个Tab 都是一个独立的进程。

实际上，我们重点关注的就是其中的Rendering engine 和 JavaScript Interpreter ，渲染引擎和解释器。说了那么多废话，我们开始了解浏览器的主流程。  
![](http://7s1s1q.com1.z0.glb.clouddn.com/2016-05-18-14635418258357.jpg)

这是浏览器从接收代码，到渲染完成的过程，从开头我们能看到它有三个主要部分：

1.  HTML/SVG/XHTML 解析，事实上，Webkit有三个C++的类对应这三类文档。解析这三种文件会产生一个DOM Tree。
2.  CSS 解析，解析CSS会产生CSS规则树。
3.  Javascript DOM，主要是通过DOM API和CSSOM API来操作DOM Tree和CSS Rule Tree.

浏览器最早开始解析HTML，将标签转化为内容树中的DOM 节点，此时识别标签的时候，HTML 解析器是无法识别哪些被实体编码的内容的，只有建立起DOM 树，才能对每个节点的内容进行识别，如果出现实体编码，则会进行实体解码。在此基础上，JavaScript DOM API 参与进来，可以对DOM 树进行修改，改变DOM树的结构和内容。而此时，CSS解析器则解析外部CSS 文件以及Style 标签中的样式内容，这些信息将搭配HTML 中的可见指令构建起一个Rendering Tree。

这里CSS 解析器在构造Redering Tree 之前，为了辅助会有CSS Rule Tree，他是为了完成匹配，然后把CSS Rule 附加给Rendering Tree 上的每个element，也就是每个DOM 节点。其中有一个layout/reflow 的过程，就是为了计算每个frame 位置等信息。

当然，个人并不是一个Web 开发者，无意在CSS 这一块花费巨大的时间，下面这个视频会很形象的让你感受到layout/reflow 的过程。[Gecko reflow visualization](http://v.youku.com/v_show/id_XMzI5MDg0OTA0.html)

完成布局之后，使用UI 后端完成每个节点的绘制，完成显示。

编码和解码发生的顺序
----------

在看完浏览器工作流程之后（当然，这个流程讲的有点简单了），我们来看一下编码和解码的顺序，对应着工作流程就很容易记清楚了。

### URL 解析

在这些所有工作流程开始之前，浏览器一定需要有一个URL 来指示资源的位置，为什么刚才没有说呢，因为这个URL 是浏览器发送给服务器的请求信息，其处理工作并不是浏览器的工作。比如我们考虑一段简单的代码：

1

2

3

4

5

6

7

8

<html\>

<head\>

<meta http-equiv\="Content-Type" content\="text/html; charset=utf-8" />

</head\>

<body\>

<a href\="javascript:alert('<?php echo $\_GET\['input'\];?>');"\>test</a\>

</body\>

</html\>

input 内容参数为： %26lt%5cu4e00%26gt

该值构造在URL 里，浏览器直接发送给服务器，服务器接收之后，先进行URL 解析，看到了% 这个符号，于是URL 解码，input 内容变成了&lt\\u4e00&gt，所以对于浏览器从服务器端获取的页面数据来说，此时test 对应的标签变成了如下：

1

<a href\="javascript:alert('<\\u4e00>');"\>test</a\>

这一步完成在所有的工作之前，URL 解码发生在第一部，而且它基本上都发生在服务器上。

### HTML 解析

浏览器接收到页面数据，于是开始进行HTML 解析，构造DOM树。构造的过程与语言的编译过程是相似的，接收文档，先进行词法分析，然后语法分析，构建解析树。

解析过程是迭代的，解析器从词法分析器处取道一个新的符号，并试着用这个符号匹配一条语法规则，如果匹配了一条规则，这个符号对应的节点将被添加到解析树上，然后解析器请求另一个符号。如果没有匹配到规则，解析器将在内部保存该符号，并从词法分析器取下一个符号，直到所有内部保存的符号能够匹配一项语法规则。如果最终没有找到匹配的规则，解析器将抛出一个异常，这意味着文档无效或是包含语法错误。

而最后输出的树，也就是这里的解析树，是由DOM元素及属性节点组成的。对于以下一个最常见的例子：

1

2

3

4

5

6

7

8

<html\>

    <body\>

        <p\>

          Hello DOM

        </p\>

        <div\><img src\=”example.png” /></div\>

    </body\>

</html\>

它将转换为下面的DOM 树：  
![](http://7s1s1q.com1.z0.glb.clouddn.com/2016-05-18-14635438180995.jpg)

所以，HTML 的分析器只能识别特定的词法规则，才能构建起DOM 树，这一块，HTML 不会做解码的工作，因为它做不了。所以，试图这样构造利用漏洞，是不可能的：

1

<img src&#x3d;"http://www.example.com">

因为在构建DOM 树的时候，这样是无法识别的，也就破坏了标签本身的结构。而HTML 解码，是在DOM树结构OK，对节点内容解析的时候，会进行转码，所以以下两种写法，是完全一样的：

1

2

<img src\="http://www.example.com"\>

<img src\="http://www.example.com"\>

所以，在DOM 树构建完毕之后，这些HTML 实体编码的内容就会被解码。JS 的解释器还没有走进战场。不过由于DOM 的存在，JavaScript还是参与了DOM Tree 的构建过程，这时候，编码的解析就变得绕了一些。在此我们先忽略掉这一个，先继续讲主过程讲完，继续考虑这个代码：

1

<a href\="javascript:alert('<\\u4e00>');"\>test</a\>

HTMl 解析器构建DOM Tree, href中的内容，如果识别为实体编码的，会透明的解码，于是它就变成了这样：

1

<a href\="javascript:alert('<\\u4e00>')"\>test</a\>

CSS 的编码问题
---------

一般来说，CSS 解析器会做接下来的工作，不过一般来说，为了考虑到更好的体验和性能，并不会等到所有的html都解析完成之后再去构建和布局render树。它是解析完一部分内容就显示一部分内容，同时，可能还在通过网络下载其余内容。

当然CSS不会干扰到DOM 树的建立，他会结合CSS文件和style 标签，以及HTML中的课件指令来构建起reder tree。这里JavaScrit 的 CSSOM api 也会出一些力。

CSS 编码解析是用了一套不太正统的转义策略：**用一个反斜杠，后边跟1~6位十六进制数字构成。**，所以字母e 可以编码为 \\65, \\065,\\000065。而因为这样，后边就不能直接紧跟数字或字母，否则会被当成转义里的内容处理，所以CSS 选择了空格作为终止标识，在解码的时候，再将空格去除。

同时，CSS还支持直接使用反斜杠对非十六进制字符进行转义的方式，就按紧跟着反斜杠后边的字符的字面意思进行解释，这种机制可用来转义引号和反斜杠本身，不过不能转义HTML 控制的字符，比如尖括号，那是因为HTML 解析器总是先于CSS 解析器。

由于CSS 转义规定的语焉不详，许多解析器会对本该用引号括起来的字符串进行任意的转义，特别的，在IE 浏览器里，这种转义优先级高于伪函数语法，于是下边两种情况的写法是一样的：

1

2

color:expression(alert(1))

color:expression\\028 alert \\028 1 \\029 \\029

如果对该部分内容感兴趣，可以阅读开始提到的那篇文章，或者是我之前写的一些文章。

JS 解释器
------

上边提到了style ，是建立reder tree 的时候使用的，它怎么工作的呢。考虑到我们的浏览器为了让不同的解析器来工作处理不同的内容，实际上，在处理诸如< script> < style> 这样的标签，解析器会自动切换到特殊解析模式，而src href 后边加入的JavaScript 伪URL，也会进入JS 的解析模式。而进入该解析模式的时候，该DOM节点已经建立起来了。

还是上边的例子，经过HTML 的解码，代码已经变成这样：

1

<a href\="javascript:alert('<\\u4e00>')"\>test</a\>

javascript 出发了JS 解释器，JS会先对内容进行解析，里边有一个转义字符\\u4e00,前导的 \\u 表示他是一个Unicode 字符，根据后边的数字，解析为’一’，于是在完成JS的解析之后变成了：

1

<a href\="javascript:alert('<一>')"\>test</a\>

然后JS 解释器执行alert(“< 一>”)，这句话会交给浏览器渲染，最终弹窗。

这里边会有一个看起来让人有些疑惑的东西，仍以上一段代码为例，假如我们编码的位置不是括号里，而是在alert上，我们知道，js 是会对它进行逆转义的：

1

<a href\="javascript:\\u0061lert('<一>')"\>test</a\>

而另一方面，如果想用这种方式来替换掉圆括号，或者引号，会判定为失败。同时，**主要注意的方式，上边这种直接在字符串外进行专一的方式，只有Unicode 转义方式呗支持，其他转义方式则不行**。其实，这样的策略是正确的，因为对于JavaScript，转义编码应当只出现在标示符部分，不能用于对语法有真正影响的符号，也就是括号，或者是引号。其实，这样的处理方法，反而是比CSS 更加合理的。

在一个页面中，可以出发JS 解析器的方式有这么几种：

*   直接嵌入< script> 代码块。
*   通过< script sr=… > 加载代码。
*   各种HTML CSS 参数支持JavaScript：URL 触发调用。
*   CSS expression(…) 语法和某些浏览器的XBL 绑定。
*   事件处理器(Event handlers),比如 onload, onerror, onclick等等。
*   定时器，Timer(setTimeout, setInterval)
*   eval(…) 调用。

我们看到，这些藏匿在HTML 便签中的各种JS 调用，就可以想到Web 开发者的头有多大了，我们举一个简单的栗子：

比如定时器那里，考虑以下代码：

1

2

3

4

5

< script>

var value = "user\_string";

...

setTimeout("do\_stuff('"+value+"')", 1000);

< /script\>

表面上看他没有问题，对 value 只做一次转义就好了，但实际呢，考虑其解析过程，首先是HTML 解析出script 块，然后JavaScript 做第一次解析，检查setTimeout 语法，而等到1秒之后，才会解析do\_stuff，如果不多做一次转义，就有可能构造成一次注入，比如user\_string 中插入一个JavaScript编码的构造，截断前边函数，然后构造自己的攻击部分。

下面我们说一说DOM，我们知道常见的DOM 操作：

DOM 常见的方法有：

*   获取节点
    *   getElementsById()
    *   getElementsByTagName()
    *   getElementsByClassName()
*   新增结点
    *   document.createElement() 创建节点对象，参数是字符串也就是html标签
    *   createTextNode 创建文本节点，配合上一个使用
    *   appendChild(element) 把新的结点添加到指定节点下，参数是一个节点对象
    *   insertChild() 在指定结点钱插入新的节点
*   修改节点
    *   replaceChild() 节点交换
    *   setAttribute() 设置属性
*   删除节点
    *   removeChild(element) 删除节点，要先获得父节点然后再删除子节点
*   一些属性
    *   innerHTML 节点内容，可以获取或者设置
    *   parentNode 当前节点的父节点
    *   childNode 子节点
    *   attributes 节点属性
    *   style 修改样式

这样就有一些疑惑了，之前，我们说了，基本的解析顺序是这样的，URL 解析器，HTML 解析器， CSS 解析器，JS解析器，如果安安静静的按照这个顺序下去，应该很容易理清楚。然而DOM 操作里我们可以看到可以新增节点，也可以修改节点属性，节点的内容和样式都可以修改。那么假如我们使用innerHTML 修改了某节点的内容，让其构成了一个新的节点，那么会有什么效果呢？我在Chrome 上做了一些实验，代码如下:

1

2

3

4

5

6

7

8

9

10

11

12

13

14

15

16

17

<html\>

<body\>

<p id\="1"\>hello</p\>

<img src\=# onerror\="alert(1)" />

<script\>

document.getElementById("1").innerHTML = "<img src=# on\\u0065rror=alert(1)>";  

</script\>

<!--<script>

document.getElementById("1").innerHTML = "<img src="1" onerror="alert(1)">";  

&#97;

</script>-->

</body\>

<html\>

一个正常的容易理解的过程是这一行：

1

<img src\=# onerror\="alert(1)" />

HTML 解析到标签，建立DOM 树，然后对节点内容进行实体解码，&#97； 就变成a, 随后在js 解析阶段，正常的触发了弹窗，先后顺序OK。

但对于下面这段代码：

1

2

3

<script>

document.getElementById("1").innerHTML = "<img src=# on\\u0065rror=alert(1)>";  

</script\>

使用了DOM 操作，修改前边标签中的内容，添加了一个img 内容，因为进入了script 进入了JavaScript的特殊解析模式，所以此处HTML 不得干扰，首先JavaScript解析器，会先对其中编码的内容解码，于是onerror 就还原回来了，于是正常的执行了JS 语句，在HTML 文档中，将hello 变成了img。

那么问题来了，如上那样，对onerror 的内容作了HTML 实体编码，会不会弹窗呢？ 答案是显然的，该标签传回给HTML，HTML 建立DOM节点，透明的解码节点内容，onerror 又会执行其中的JS 脚本，弹出窗口。

其实，这里也不难理解，因为HTML 是从上到下解析，遇到< script> 于是进入了特殊的解析模式，使用JS 解析器，做了一个DOM 操作，该DOM 操作修改了前边的DOM 树，该块内容，需要使用HTML 解析重塑DOM 树，那么节点内容中的实体编码就会被解码，然后onerror 中触发脚本，JS 又会对内容进行一次解析。

这一点很好理解：

1

<img src="1" onerror="al\\u0065rt(1)" />

如上，内容中有HTML实体编码，还有js 的Unicode 编码，正常弹窗没有问题。

总结说来，实际上，DOM 操作实际上是js强势介入 HTML 和CSS 的结果，使用DOM 操作，对DOM Tree 造成了改变，会调用到HTML 解析器重新对其解析，于是流程又会返回到最开始说的那个解析流程里去。这样反复的情况，再加上编码的重叠，很容易让开发者无所适从，考虑下面的代码：

1

2

3

4

5

6

7

8

9

10

11

12

13

14

15

16

<p id="1">hello</p>

<img src="1" onerror="al\\u0065rt(1)" />

<script>

document.getElementById("1").innerHTML = "bye";

function a(){

document.getElementById("1").innerHTML = "<img src=# on\\u0065rror=alert(1)>";

}

function timedMsg()

{

var t=setTimeout("a()",5000)

}

</script>

<input type="button" value="111" onClick = "timedMsg()" />

整个页面渲染完毕，而当点击按钮之后，会触发DOM操作的脚本，五秒钟之后，弹窗。

如果想要修改的内容中有脚本，内容中的脚本部分使用JS编码，再使用HTML 编码，然后再使用JS Unicode编码，那么解码的过程就是先JS 解码，再HTML 解码，再JS 解码，然后执行。

总结
--

其实总的来说，其道理还是易于理解的，只是由于一些特别的操作，造成了一些困扰，于是在编码上，会理不清头绪，如果再此基础上我们再使用String.fromCharCode() 这个一直以来容易被开发者忽略的功能，更会摸不清头脑。

而正是由于这种摸不清头脑的开发之下，黑客们才有可趁之机，制造各种变体，绕过孱弱的过滤器。

总体来说，在编码这件事上，只要理清楚，URL解码，HTML解码，CSS解码，JS解码，以及DOM 操作在其中扮演的角色，就基本上能理清楚了。作为一个开发者，安全编码是必须要重视的内容，所以，对于编码，不可以逃避，在构建安全的过滤规则的时候，一定要考虑清楚各种可能的编码绕过的方式,以避免损失。

如何避免这些漏洞的产生，我会再以后继续写，关于浏览器的解码过程就写到这里吧。对这一问题，仍然还有一些问题有待解决，个人能力有限，其中也有可能存在错误和疏漏，请谅解~

PS. 参考：开头提到的文章，W3cschool 上各种函数，各种编码。《The Tangled Web》这本神书，和一堆谷歌搜索。
