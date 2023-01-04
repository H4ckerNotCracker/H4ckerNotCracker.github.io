---
title: FRP改造计划续
date: 2020-12-28 19:00:00
tags:
---



### 前言

之前@Wfox师傅在群里提到“通过websocket协议让FRP用上域前置，可以隐藏真实服务ip地址”。最近没有项目，重新进行一下frp改造计划。

### 可行性证明

先用dns域名解析来证明域前置方案在frp上是可行的，这里也可以直接修改本地hosts文件来实现dns域名解析的效果。

比如我们用如下frpc.ini

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

\[common\]  
server\_addr = dwnwdqndlnqwln2321321.com  
server\_port = 23333  
token = uknowsec  
protocol = websocket  
tls\_enable = true  
  
\[http\_proxy\]  
type = tcp  
remote\_port = 10002  
plugin = socks5  

让frpc认证数据包走websocket协议。

![image-20201229234612622](https://uknowsec-1251971873.cos.ap-shanghai.myqcloud.com\image-20201229234612622.png)

可以看到认证是通过websocket协议，这里特别标注出来了Host头，要实现域前置，我们只要把host修改为我们的指定回源域名即可。所以证明了“通过websocket协议让FRP用上域前置”是可行的。

### Websocket依赖修改

跟进frp源码，我们可以到websocket依赖包`websocket/hybi.go`文件下的hybiClientHandshake函数。

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
18  
19  

func hybiClientHandshake(config \*Config, br \*bufio.Reader, bw \*bufio.Writer) (err error) {  
 bw.WriteString("GET " + config.Location.RequestURI() + " HTTP/1.1\\r\\n")  
  
 // According to RFC 6874, an HTTP client, proxy, or other  
 // intermediary must remove any IPv6 zone identifier attached  
 // to an outgoing URI.  
 bw.WriteString("Host: " + removeZone(config.Location.Host) + "\\r\\n")  
 bw.WriteString("Upgrade: websocket\\r\\n")  
 bw.WriteString("Connection: Upgrade\\r\\n")  
 nonce := generateNonce()  
 if config.handshakeData != nil {  
 nonce = \[\]byte(config.handshakeData\["key"\])  
 }  
 bw.WriteString("Sec-WebSocket-Key: " + string(nonce) + "\\r\\n")  
 bw.WriteString("Origin: " + strings.ToLower(config.Origin.String()) + "\\r\\n")  
  
 ...  
 return nil  
}  

可以看到Host是通过`config.Location.Host`进行赋值的，我们再一步一步的往回看调用即可。

同时frp调用`websocket`依赖在`pkg/util/net/websocket.go`里的`ConnectWebsocketServer`方法

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
18  
19  
20  
21  
22  

func ConnectWebsocketServer(addr string) (net.Conn, error) {  
 addr = "ws://" + addr + FrpWebsocketPath  
 uri, err := url.Parse(addr)  
 if err != nil {  
 return nil, err  
 }  
  
 origin := "http://" + uri.Host  
 cfg, err := websocket.NewConfig(addr, origin)  
 if err != nil {  
 return nil, err  
 }  
 cfg.Dialer = &net.Dialer{  
 Timeout: 10 \* time.Second,  
 }  
  
 conn, err := websocket.DialConfig(cfg)  
 if err != nil {  
 return nil, err  
 }  
 return conn, nil  
}  

所以只需要在往`websocket.NewConfig`多传入一个指定的host参数即可。

新加入的host参数只要在`cmd/frpc/sub/root.go`的`RegisterCommonFlags`里进行注册即可。

#### 测试效果

![image-20201230002508915](https://uknowsec-1251971873.cos.ap-shanghai.myqcloud.com\image-20201230002508915.png)

这样我们就实现了`通过websocket协议让FRP用上域前置`。

### WSS实现

由上图，可见用websocket还是特征比较明显的，比如`/~!frp`。这里我们可以通过如下修改

`pkg/util/net/websocket.go`下的变量即可。

1  
2  
3  

const (  
 FrpWebsocketPath = "/~!frp"  
)  

同时，我们也修改frp使之实现wss协议。

@Wfox师傅提醒frp有人pull了支持wss协议的修改代码。

[https://github.com/fatedier/frp/pull/1919/files](https://github.com/fatedier/frp/pull/1919/files)

通过pull里的修改就可以实现wss协议了

同时由于在某云域前置里，用wss协议的情况下，server\_addr用域名会不能正常回源，只能用ip。且会存在证书报错。

![image-20201230003824977](https://uknowsec-1251971873.cos.ap-shanghai.myqcloud.com\image-20201230003824977.png)

这里可以通过做如下修改`pkg/util/net/websocket.go`里的`ConnectWebsocketServer`函数

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
18  
19  
20  
21  
22  
23  
24  
25  
26  
27  
28  
29  
30  
31  
32  
33  
34  
35  
36  
37  
38  
39  
40  
41  
42  
43  
44  
45  

// addr: domain:port  
func ConnectWebsocketServer(addr string, websocket\_domain string, isSecure bool) (net.Conn, error) {  
 if isSecure {  
 ho := strings.Split(addr, ":")  
 ip, err := net.ResolveIPAddr("ip", ho\[0\])  
 ip\_addr := ip.String() + ":" + ho\[1\]  
 if err != nil {  
 return nil, err  
 }  
 addr = "wss://" + ip\_addr + FrpWebsocketPath  
 } else {  
 addr = "ws://" + addr + FrpWebsocketPath  
 }  
 uri, err := url.Parse(addr)  
 if err != nil {  
 return nil, err  
 }  
  
 var origin string  
 if isSecure {  
 ho := strings.Split(uri.Host, ":")  
 ip, err := net.ResolveIPAddr("ip", ho\[0\])  
 ip\_addr := ip.String() + ":" + ho\[1\]  
 if err != nil {  
 return nil, err  
 }  
 origin = "https://" + ip\_addr  
 } else {  
 origin = "http://" + uri.Host  
 }  
  
 cfg, err := websocket.NewConfig(addr, origin, websocket\_domain)  
 if err != nil {  
 return nil, err  
 }  
 cfg.Dialer = &net.Dialer{  
 Timeout: 10 \* time.Second,  
 }  
  
 conn, err := websocket.DialConfig(cfg)  
 if err != nil {  
 return nil, err  
 }  
 return conn, nil  
}  

用`net.ResolveIPAddr`先获取域名所对应ip地址，再进行wss和https协议的使用即可。

另外修复证书错误问题。

修改`websocket/dial.go`里的`dialWithDialer`方法。

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

func dialWithDialer(dialer \*net.Dialer, config \*Config) (conn net.Conn, err error) {  
 switch config.Location.Scheme {  
 case "ws":  
 conn, err = dialer.Dial("tcp", parseAuthority(config.Location))  
  
 case "wss":  
 config.TlsConfig = &tls.Config{  
 InsecureSkipVerify: true,  
 }  
 conn, err = tls.DialWithDialer(dialer, "tcp", parseAuthority(config.Location), config.TlsConfig)  
  
 default:  
 err = ErrBadScheme  
 }  
 return  
}  

当使用wss协议的时候，将`TlsConfig.InsecureSkipVerify`设置为true，即可忽略证书错误了。

#### 测试效果

![image-20201230003610771](https://uknowsec-1251971873.cos.ap-shanghai.myqcloud.com\image-20201230003610771.png)

可见图中的认证数据包已经以wss进行认证了。

### 配置文件自删除

在其中看@lz520520师傅的文章里看到

[https://sec.lz520520.cn:4430/2020/11/566/#0x03](https://sec.lz520520.cn:4430/2020/11/566/#0x03)

> 只要读取后删除配置文件就好了呀，这个就很简单，我多添加了一个配置文件参数delete，用于判断是否自动删除配置文件。

这一点还是不错的，添加参数，读取完配置文件启动frpc后，自动删除配置文件。

同样相同的方法在`cmd/frpc/sub/root.go`的`RegisterCommonFlags`里进行注册参数即可。

然后在`cmd/frpc/sub/root.go`里的`startService`方法里进行判断调用删除配置文件即可。

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
18  
19  
20  
21  
22  
23  
24  
25  
26  
27  
28  
29  
30  
31  
32  
33  
34  
35  
36  
37  
38  
39  
40  
41  
42  

func startService(  
 cfg config.ClientCommonConf,  
 pxyCfgs map\[string\]config.ProxyConf,  
 visitorCfgs map\[string\]config.VisitorConf,  
 cfgFile string,  
) (err error) {  
  
 log.InitLog(cfg.LogWay, cfg.LogFile, cfg.LogLevel,  
 cfg.LogMaxDays, cfg.DisableLogColor)  
  
 if cfg.DNSServer != "" {  
 s := cfg.DNSServer  
 if !strings.Contains(s, ":") {  
 s += ":53"  
 }  
 // Change default dns server for frpc  
 net.DefaultResolver = &net.Resolver{  
 PreferGo: true,  
 Dial: func(ctx context.Context, network, address string) (net.Conn, error) {  
 return net.Dial("udp", s)  
 },  
 }  
 }  
 svr, errRet := client.NewService(cfg, pxyCfgs, visitorCfgs, cfgFile)  
 if errRet != nil {  
 err = errRet  
 return  
 }  
 if cfg.DELEnable == true {  
 os.Remove(cfgFile)  
 }  
 // Capture the exit signal if we use kcp.  
 if cfg.Protocol == "kcp" {  
 go handleSignal(svr)  
 }  
  
 err = svr.Run()  
 if cfg.Protocol == "kcp" {  
 <-kcpDoneCh  
 }  
 return  
}  

这样就可以实现配置文件自动删除功能了。

### Github

没有环境或无法正常编译可直接到github下载

[https://github.com/uknowsec/frpModify](https://github.com/uknowsec/frpModify)

### Reference

[https://github.com/fatedier/frp/pull/1919/files](https://github.com/fatedier/frp/pull/1919/files)

[https://sec.lz520520.cn:4430/2020/11/566/](https://sec.lz520520.cn:4430/2020/11/566/)

[NEXT](/posts/notes/OXID_Find：通过OXID解析器获取Windows远程主机上网卡地址.html)