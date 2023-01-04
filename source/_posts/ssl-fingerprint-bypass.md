---
title: SSL 指纹识别和绕过
date: 2021-05-02 15:30:00
tags:
---


SSL 指纹识别和绕过
===========

[](#SSL-Fingerprint-and-Bypass "SSL Fingerprint and Bypass")[](#SSL-Fingerprint-and-Bypass "SSL Fingerprint and Bypass")SSL Fingerprint and Bypass
==================================================================================================================================================

之前搞某个网站发现使用不同客户端发起请求会有不同的响应结果，就很神奇

[](#Python-403-Burp-200 "Python 403 Burp 200?")[](#Python-403-Burp-200 "Python 403 Burp 200?")Python 403 Burp 200?
==================================================================================================================

先看两个不同客户端发起的请求结果

[](#Burp "Burp")[](#Burp "Burp")Burp
------------------------------------

![image-20210417230416894](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/d2391c72b63388302ca7b5a22ee7eed9.png)

[](#Python3-Requests "Python3 Requests")[](#Python3-Requests "Python3 Requests")Python3 Requests
------------------------------------------------------------------------------------------------

同样的请求复制到python3中用requests发包:

    <body data-spm="7663354">
      <div data-spm="1998410538">
        <div class="header">
          <div class="container">
            <div class="message">
              很抱歉，由于您访问的URL有可能对网站造成安全威胁，您的访问被阻断。
              <div>您的请求ID是: <strong>
    276aedd416186716424122798e3951</strong></div>
            </div>
          </div>
        </div>
        <div class="main">
          <div class="container">

一样的请求地址一样的参数一样的http header，burp发送的请求正常响应，python发送的被waf拦截，curl模拟请求也被拦截

waf 是阿里云的waf，dig域名也能看出来 ，cname 解析到了`xxx.yundunwaf3.com`

多地ping发现并没有cdn，不是cdnwaf

> 其实第一种解决方法已经出来了，直接ping域名获取真实ip，request直接请求ip地址，在Header中指定Host即可绕过waf的弱智拦截

网上搜了一下相关内容

![image-20210418010259647](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/240913a382ea1c10ce9bbf61633f3d93.png)

本来以为是ua的问题，后来更换了ua发现并没有什么卵用

问了问朋友，说python的tls握手有特征

在网上搜了一下，发现确实有很多类似的问题

*   [https://stackoverflow.com/questions/60407057/python-requests-being-fingerprinted](https://stackoverflow.com/questions/60407057/python-requests-being-fingerprinted)
*   [https://stackoverflow.com/questions/64967706/python-requests-https-code-403-without-but-code-200-when-using-burpsuite](https://stackoverflow.com/questions/64967706/python-requests-https-code-403-without-but-code-200-when-using-burpsuite)
*   [https://stackoverflow.com/questions/63343106/how-to-avoid-request-fingerprinted-in-python](https://stackoverflow.com/questions/63343106/how-to-avoid-request-fingerprinted-in-python)

[](#不同客户端的ClientHello报文 "不同客户端的ClientHello报文")[](#%E4%B8%8D%E5%90%8C%E5%AE%A2%E6%88%B7%E7%AB%AF%E7%9A%84ClientHello%E6%8A%A5%E6%96%87 "不同客户端的ClientHello报文")不同客户端的ClientHello报文
===============================================================================================================================================================================

掏出了安装完从来没用过的wireshark抓了几个不同客户端的请求包

客户端发起https的请求第一步是向服务器发送tls握手请求，其中就包含了客户端的一些特征

相关内容在tls协议报文中`Client Hello`的`Transport Layer Security`当中

![image-20210417235004781](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/6991f12ea1050320a4c5d05bd06eebff.png)

抓了几个常用客户端的流量瞅瞅

[](#CURL-ClientHello "CURL ClientHello")[](#CURL-ClientHello "CURL ClientHello")CURL ClientHello
------------------------------------------------------------------------------------------------

    curl 7.76.0 (x86_64-apple-darwin19.6.0) libcurl/7.76.0 (SecureTransport) OpenSSL/1.1.1k zlib/1.2.11 brotli/1.0.9 zstd/1.4.9 libidn2/2.3.0 libssh2/1.9.0 nghttp2/1.43.0 librtmp/2.3

    TLSv1.2 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.0 (0x0301)
        Length: 512
        Handshake Protocol: Client Hello
            Handshake Type: Client Hello (1)
            Length: 508
            Version: TLS 1.2 (0x0303)
            Random: b828dcc000f8561e4075538e80c600cfd74ae17371213a4cefd39888aaed48da
                GMT Unix Time: Nov 28, 2067 14:01:36.000000000 CST
                Random Bytes: 00f8561e4075538e80c600cfd74ae17371213a4cefd39888aaed48da
            Session ID Length: 32
            Session ID: c27bcf013c1e94fa502967ee1a1249b6aa73f381af1eff935e0fc05ee1e22764
            Cipher Suites Length: 62
            Cipher Suites (31 suites)
                Cipher Suite: TLS_AES_256_GCM_SHA384 (0x1302)
                Cipher Suite: TLS_CHACHA20_POLY1305_SHA256 (0x1303)
                Cipher Suite: TLS_AES_128_GCM_SHA256 (0x1301)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02c)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (0xc030)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_GCM_SHA384 (0x009f)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca9)
                Cipher Suite: TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca8)
                Cipher Suite: TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xccaa)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 (0xc02b)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (0xc02f)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 (0x009e)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384 (0xc024)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (0xc028)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA256 (0x006b)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256 (0xc023)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (0xc027)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA256 (0x0067)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA (0xc00a)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (0xc014)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA (0x0039)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA (0xc009)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (0xc013)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA (0x0033)
                Cipher Suite: TLS_RSA_WITH_AES_256_GCM_SHA384 (0x009d)
                Cipher Suite: TLS_RSA_WITH_AES_128_GCM_SHA256 (0x009c)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA256 (0x003d)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA256 (0x003c)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA (0x0035)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA (0x002f)
                Cipher Suite: TLS_EMPTY_RENEGOTIATION_INFO_SCSV (0x00ff)
            Compression Methods Length: 1
            Compression Methods (1 method)
                Compression Method: null (0)
            Extensions Length: 373
            Extension: server_name (len=22)
                Type: server_name (0)
                Length: 22
                Server Name Indication extension
                    Server Name list length: 20
                    Server Name Type: host_name (0)
                    Server Name length: 17
                    Server Name: xxxx.xxxx.com
            Extension: ec_point_formats (len=4)
                Type: ec_point_formats (11)
                Length: 4
                EC point formats Length: 3
                Elliptic curves point formats (3)
                    EC point format: uncompressed (0)
                    EC point format: ansiX962_compressed_prime (1)
                    EC point format: ansiX962_compressed_char2 (2)
            Extension: supported_groups (len=12)
                Type: supported_groups (10)
                Length: 12
                Supported Groups List Length: 10
                Supported Groups (5 groups)
            Extension: next_protocol_negotiation (len=0)
                Type: next_protocol_negotiation (13172)
                Length: 0
            Extension: application_layer_protocol_negotiation (len=14)
                Type: application_layer_protocol_negotiation (16)
                Length: 14
                ALPN Extension Length: 12
                ALPN Protocol
                    ALPN string length: 2
                    ALPN Next Protocol: h2
                    ALPN string length: 8
                    ALPN Next Protocol: http/1.1
            Extension: encrypt_then_mac (len=0)
                Type: encrypt_then_mac (22)
                Length: 0
            Extension: extended_master_secret (len=0)
                Type: extended_master_secret (23)
                Length: 0
            Extension: post_handshake_auth (len=0)
                Type: post_handshake_auth (49)
                Length: 0
            Extension: signature_algorithms (len=48)
                Type: signature_algorithms (13)
                Length: 48
                Signature Hash Algorithms Length: 46
                Signature Hash Algorithms (23 algorithms)
                    Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp384r1_sha384 (0x0503)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp521r1_sha512 (0x0603)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ed25519 (0x0807)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (7)
                    Signature Algorithm: ed448 (0x0808)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (8)
                    Signature Algorithm: rsa_pss_pss_sha256 (0x0809)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (9)
                    Signature Algorithm: rsa_pss_pss_sha384 (0x080a)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (10)
                    Signature Algorithm: rsa_pss_pss_sha512 (0x080b)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (11)
                    Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (4)
                    Signature Algorithm: rsa_pss_rsae_sha384 (0x0805)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (5)
                    Signature Algorithm: rsa_pss_rsae_sha512 (0x0806)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (6)
                    Signature Algorithm: rsa_pkcs1_sha256 (0x0401)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha384 (0x0501)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha512 (0x0601)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 ECDSA (0x0303)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_sha1 (0x0203)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: SHA224 RSA (0x0301)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha1 (0x0201)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 DSA (0x0302)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA1 DSA (0x0202)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA256 DSA (0x0402)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA384 DSA (0x0502)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA512 DSA (0x0602)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: DSA (2)
            Extension: supported_versions (len=9)
                Type: supported_versions (43)
                Length: 9
                Supported Versions length: 8
                Supported Version: TLS 1.3 (0x0304)
                Supported Version: TLS 1.2 (0x0303)
                Supported Version: TLS 1.1 (0x0302)
                Supported Version: TLS 1.0 (0x0301)
            Extension: psk_key_exchange_modes (len=2)
                Type: psk_key_exchange_modes (45)
                Length: 2
                PSK Key Exchange Modes Length: 1
                PSK Key Exchange Mode: PSK with (EC)DHE key establishment (psk_dhe_ke) (1)
            Extension: key_share (len=38)
                Type: key_share (51)
                Length: 38
                Key Share extension
            Extension: padding (len=172)
                Type: padding (21)
                Length: 172
                Padding Data: 000000000000000000000000000000000000000000000000000000000000000000000000…

[](#Python3-Requests-1 "Python3 Requests")[](#Python3-Requests-1 "Python3 Requests")Python3 Requests
----------------------------------------------------------------------------------------------------

    macOS 10.15.7
    requests          2.23.0
    OpenSSL 1.1.1f  31 Mar 2020

    TLSv1.2 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.0 (0x0301)
        Length: 338
        Handshake Protocol: Client Hello
            Handshake Type: Client Hello (1)
            Length: 334
            Version: TLS 1.2 (0x0303)
            Random: ba70fc87a4c2f484780452456788606ce8c7143580264df3c3a29ae1d0b6b7a4
                GMT Unix Time: Feb 13, 2069 15:40:55.000000000 CST
                Random Bytes: a4c2f484780452456788606ce8c7143580264df3c3a29ae1d0b6b7a4
            Session ID Length: 32
            Session ID: b5aed6d7fa7c369cea55573184dfc73d096c53eca3a9702ce48ce1381e525ade
            Cipher Suites Length: 86
            Cipher Suites (43 suites)
                Cipher Suite: TLS_AES_256_GCM_SHA384 (0x1302)
                Cipher Suite: TLS_CHACHA20_POLY1305_SHA256 (0x1303)
                Cipher Suite: TLS_AES_128_GCM_SHA256 (0x1301)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02c)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (0xc030)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 (0xc02b)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (0xc02f)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca9)
                Cipher Suite: TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca8)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_GCM_SHA384 (0x009f)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 (0x009e)
                Cipher Suite: TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xccaa)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CCM_8 (0xc0af)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CCM (0xc0ad)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CCM_8 (0xc0ae)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CCM (0xc0ac)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384 (0xc024)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (0xc028)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256 (0xc023)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (0xc027)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA (0xc00a)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (0xc014)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA (0xc009)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (0xc013)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CCM_8 (0xc0a3)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CCM (0xc09f)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CCM_8 (0xc0a2)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CCM (0xc09e)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA256 (0x006b)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA256 (0x0067)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA (0x0039)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA (0x0033)
                Cipher Suite: TLS_RSA_WITH_AES_256_GCM_SHA384 (0x009d)
                Cipher Suite: TLS_RSA_WITH_AES_128_GCM_SHA256 (0x009c)
                Cipher Suite: TLS_RSA_WITH_AES_256_CCM_8 (0xc0a1)
                Cipher Suite: TLS_RSA_WITH_AES_256_CCM (0xc09d)
                Cipher Suite: TLS_RSA_WITH_AES_128_CCM_8 (0xc0a0)
                Cipher Suite: TLS_RSA_WITH_AES_128_CCM (0xc09c)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA256 (0x003d)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA256 (0x003c)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA (0x0035)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA (0x002f)
                Cipher Suite: TLS_EMPTY_RENEGOTIATION_INFO_SCSV (0x00ff)
            Compression Methods Length: 1
            Compression Methods (1 method)
                Compression Method: null (0)
            Extensions Length: 175
            Extension: server_name (len=22)
                Type: server_name (0)
                Length: 22
                Server Name Indication extension
                    Server Name list length: 20
                    Server Name Type: host_name (0)
                    Server Name length: 17
                    Server Name: xxxx.xxxx.com
            Extension: ec_point_formats (len=4)
                Type: ec_point_formats (11)
                Length: 4
                EC point formats Length: 3
                Elliptic curves point formats (3)
                    EC point format: uncompressed (0)
                    EC point format: ansiX962_compressed_prime (1)
                    EC point format: ansiX962_compressed_char2 (2)
            Extension: supported_groups (len=12)
                Type: supported_groups (10)
                Length: 12
                Supported Groups List Length: 10
                Supported Groups (5 groups)
            Extension: session_ticket (len=0)
                Type: session_ticket (35)
                Length: 0
                Data (0 bytes)
            Extension: encrypt_then_mac (len=0)
                Type: encrypt_then_mac (22)
                Length: 0
            Extension: extended_master_secret (len=0)
                Type: extended_master_secret (23)
                Length: 0
            Extension: signature_algorithms (len=48)
                Type: signature_algorithms (13)
                Length: 48
                Signature Hash Algorithms Length: 46
                Signature Hash Algorithms (23 algorithms)
                    Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp384r1_sha384 (0x0503)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp521r1_sha512 (0x0603)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ed25519 (0x0807)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (7)
                    Signature Algorithm: ed448 (0x0808)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (8)
                    Signature Algorithm: rsa_pss_pss_sha256 (0x0809)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (9)
                    Signature Algorithm: rsa_pss_pss_sha384 (0x080a)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (10)
                    Signature Algorithm: rsa_pss_pss_sha512 (0x080b)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (11)
                    Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (4)
                    Signature Algorithm: rsa_pss_rsae_sha384 (0x0805)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (5)
                    Signature Algorithm: rsa_pss_rsae_sha512 (0x0806)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (6)
                    Signature Algorithm: rsa_pkcs1_sha256 (0x0401)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha384 (0x0501)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha512 (0x0601)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 ECDSA (0x0303)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_sha1 (0x0203)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: SHA224 RSA (0x0301)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha1 (0x0201)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 DSA (0x0302)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA1 DSA (0x0202)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA256 DSA (0x0402)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA384 DSA (0x0502)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA512 DSA (0x0602)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: DSA (2)
            Extension: supported_versions (len=9)
                Type: supported_versions (43)
                Length: 9
                Supported Versions length: 8
                Supported Version: TLS 1.3 (0x0304)
                Supported Version: TLS 1.2 (0x0303)
                Supported Version: TLS 1.1 (0x0302)
                Supported Version: TLS 1.0 (0x0301)
            Extension: psk_key_exchange_modes (len=2)
                Type: psk_key_exchange_modes (45)
                Length: 2
                PSK Key Exchange Modes Length: 1
                PSK Key Exchange Mode: PSK with (EC)DHE key establishment (psk_dhe_ke) (1)
            Extension: key_share (len=38)
                Type: key_share (51)
                Length: 38
                Key Share extension

[](#Python3-aioHTTP "Python3 aioHTTP")[](#Python3-aioHTTP "Python3 aioHTTP")Python3 aioHTTP
-------------------------------------------------------------------------------------------

    3.7.4.post0

    TLSv1.2 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.0 (0x0301)
        Length: 512
        Handshake Protocol: Client Hello
            Handshake Type: Client Hello (1)
            Length: 508
            Version: TLS 1.2 (0x0303)
            Random: 950340b4f7c16cafa4080ff5144082923c907cdda2e2aefa624af1dd4347e765
                GMT Unix Time: Mar 22, 2049 17:32:36.000000000 CST
                Random Bytes: f7c16cafa4080ff5144082923c907cdda2e2aefa624af1dd4347e765
            Session ID Length: 32
            Session ID: 7f921fa357f4a39367e8540dc44c1eac925a8f44c506887c4b1e5e5815a013ec
            Cipher Suites Length: 62
            Cipher Suites (31 suites)
                Cipher Suite: TLS_AES_256_GCM_SHA384 (0x1302)
                Cipher Suite: TLS_CHACHA20_POLY1305_SHA256 (0x1303)
                Cipher Suite: TLS_AES_128_GCM_SHA256 (0x1301)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02c)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (0xc030)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_GCM_SHA384 (0x009f)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca9)
                Cipher Suite: TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca8)
                Cipher Suite: TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xccaa)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 (0xc02b)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (0xc02f)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 (0x009e)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384 (0xc024)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (0xc028)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA256 (0x006b)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256 (0xc023)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (0xc027)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA256 (0x0067)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA (0xc00a)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (0xc014)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA (0x0039)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA (0xc009)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (0xc013)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA (0x0033)
                Cipher Suite: TLS_RSA_WITH_AES_256_GCM_SHA384 (0x009d)
                Cipher Suite: TLS_RSA_WITH_AES_128_GCM_SHA256 (0x009c)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA256 (0x003d)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA256 (0x003c)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA (0x0035)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA (0x002f)
                Cipher Suite: TLS_EMPTY_RENEGOTIATION_INFO_SCSV (0x00ff)
            Compression Methods Length: 1
            Compression Methods (1 method)
                Compression Method: null (0)
            Extensions Length: 373
            Extension: server_name (len=22)
                Type: server_name (0)
                Length: 22
                Server Name Indication extension
                    Server Name list length: 20
                    Server Name Type: host_name (0)
                    Server Name length: 17
                    Server Name: xxxx.xxxx.com
            Extension: ec_point_formats (len=4)
                Type: ec_point_formats (11)
                Length: 4
                EC point formats Length: 3
                Elliptic curves point formats (3)
                    EC point format: uncompressed (0)
                    EC point format: ansiX962_compressed_prime (1)
                    EC point format: ansiX962_compressed_char2 (2)
            Extension: supported_groups (len=12)
                Type: supported_groups (10)
                Length: 12
                Supported Groups List Length: 10
                Supported Groups (5 groups)
            Extension: session_ticket (len=0)
                Type: session_ticket (35)
                Length: 0
                Data (0 bytes)
            Extension: encrypt_then_mac (len=0)
                Type: encrypt_then_mac (22)
                Length: 0
            Extension: extended_master_secret (len=0)
                Type: extended_master_secret (23)
                Length: 0
            Extension: signature_algorithms (len=48)
                Type: signature_algorithms (13)
                Length: 48
                Signature Hash Algorithms Length: 46
                Signature Hash Algorithms (23 algorithms)
                    Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp384r1_sha384 (0x0503)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp521r1_sha512 (0x0603)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ed25519 (0x0807)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (7)
                    Signature Algorithm: ed448 (0x0808)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (8)
                    Signature Algorithm: rsa_pss_pss_sha256 (0x0809)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (9)
                    Signature Algorithm: rsa_pss_pss_sha384 (0x080a)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (10)
                    Signature Algorithm: rsa_pss_pss_sha512 (0x080b)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (11)
                    Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (4)
                    Signature Algorithm: rsa_pss_rsae_sha384 (0x0805)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (5)
                    Signature Algorithm: rsa_pss_rsae_sha512 (0x0806)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (6)
                    Signature Algorithm: rsa_pkcs1_sha256 (0x0401)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha384 (0x0501)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha512 (0x0601)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 ECDSA (0x0303)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_sha1 (0x0203)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: SHA224 RSA (0x0301)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha1 (0x0201)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 DSA (0x0302)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA1 DSA (0x0202)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA256 DSA (0x0402)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA384 DSA (0x0502)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA512 DSA (0x0602)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: DSA (2)
            Extension: supported_versions (len=9)
                Type: supported_versions (43)
                Length: 9
                Supported Versions length: 8
                Supported Version: TLS 1.3 (0x0304)
                Supported Version: TLS 1.2 (0x0303)
                Supported Version: TLS 1.1 (0x0302)
                Supported Version: TLS 1.0 (0x0301)
            Extension: psk_key_exchange_modes (len=2)
                Type: psk_key_exchange_modes (45)
                Length: 2
                PSK Key Exchange Modes Length: 1
                PSK Key Exchange Mode: PSK with (EC)DHE key establishment (psk_dhe_ke) (1)
            Extension: key_share (len=38)
                Type: key_share (51)
                Length: 38
                Key Share extension
            Extension: padding (len=194)
                Type: padding (21)
                Length: 194
                Padding Data: 000000000000000000000000000000000000000000000000000000000000000000000000…

[](#Burp-Suite "Burp Suite")[](#Burp-Suite "Burp Suite")Burp Suite
------------------------------------------------------------------

    [Expert Info (Comment/Comment): Burp Suite v 2021.3.2
    jdk-11.0.5]

    TLSv1.2 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.2 (0x0303)
        Length: 466
        Handshake Protocol: Client Hello
            Handshake Type: Client Hello (1)
            Length: 462
            Version: TLS 1.2 (0x0303)
            Random: 67c3b8bc51ef0e92822fc93228b970047447c83cf6f354393f99a114d9f13980
                GMT Unix Time: Mar  2, 2025 09:47:40.000000000 CST
                Random Bytes: 51ef0e92822fc93228b970047447c83cf6f354393f99a114d9f13980
            Session ID Length: 32
            Session ID: 1dd88665cef5c0afa05f4ab8ce2f861881c820c2fd5cf5ab76c3262e2534ec15
            Cipher Suites Length: 104
            Cipher Suites (52 suites)
                Cipher Suite: TLS_AES_128_GCM_SHA256 (0x1301)
                Cipher Suite: TLS_AES_256_GCM_SHA384 (0x1302)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02c)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 (0xc02b)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (0xc030)
                Cipher Suite: TLS_RSA_WITH_AES_256_GCM_SHA384 (0x009d)
                Cipher Suite: TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02e)
                Cipher Suite: TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384 (0xc032)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_GCM_SHA384 (0x009f)
                Cipher Suite: TLS_DHE_DSS_WITH_AES_256_GCM_SHA384 (0x00a3)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (0xc02f)
                Cipher Suite: TLS_RSA_WITH_AES_128_GCM_SHA256 (0x009c)
                Cipher Suite: TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256 (0xc02d)
                Cipher Suite: TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256 (0xc031)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_GCM_SHA256 (0x009e)
                Cipher Suite: TLS_DHE_DSS_WITH_AES_128_GCM_SHA256 (0x00a2)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384 (0xc024)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384 (0xc028)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA256 (0x003d)
                Cipher Suite: TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384 (0xc026)
                Cipher Suite: TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384 (0xc02a)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA256 (0x006b)
                Cipher Suite: TLS_DHE_DSS_WITH_AES_256_CBC_SHA256 (0x006a)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA (0xc00a)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (0xc014)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA (0x0035)
                Cipher Suite: TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA (0xc005)
                Cipher Suite: TLS_ECDH_RSA_WITH_AES_256_CBC_SHA (0xc00f)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_256_CBC_SHA (0x0039)
                Cipher Suite: TLS_DHE_DSS_WITH_AES_256_CBC_SHA (0x0038)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256 (0xc023)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256 (0xc027)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA256 (0x003c)
                Cipher Suite: TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256 (0xc025)
                Cipher Suite: TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256 (0xc029)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA256 (0x0067)
                Cipher Suite: TLS_DHE_DSS_WITH_AES_128_CBC_SHA256 (0x0040)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA (0xc009)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (0xc013)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA (0x002f)
                Cipher Suite: TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA (0xc004)
                Cipher Suite: TLS_ECDH_RSA_WITH_AES_128_CBC_SHA (0xc00e)
                Cipher Suite: TLS_DHE_RSA_WITH_AES_128_CBC_SHA (0x0033)
                Cipher Suite: TLS_DHE_DSS_WITH_AES_128_CBC_SHA (0x0032)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA (0xc008)
                Cipher Suite: TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA (0xc012)
                Cipher Suite: TLS_RSA_WITH_3DES_EDE_CBC_SHA (0x000a)
                Cipher Suite: TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA (0xc003)
                Cipher Suite: TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA (0xc00d)
                Cipher Suite: TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA (0x0016)
                Cipher Suite: TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA (0x0013)
                Cipher Suite: TLS_EMPTY_RENEGOTIATION_INFO_SCSV (0x00ff)
            Compression Methods Length: 1
            Compression Methods (1 method)
                Compression Method: null (0)
            Extensions Length: 285
            Extension: server_name (len=22)
                Type: server_name (0)
                Length: 22
                Server Name Indication extension
                    Server Name list length: 20
                    Server Name Type: host_name (0)
                    Server Name length: 17
                    Server Name: xxxx.xxxx.com
            Extension: status_request (len=5)
                Type: status_request (5)
                Length: 5
                Certificate Status Type: OCSP (1)
                Responder ID list Length: 0
                Request Extensions Length: 0
            Extension: supported_groups (len=18)
                Type: supported_groups (10)
                Length: 18
                Supported Groups List Length: 16
                Supported Groups (8 groups)
            Extension: ec_point_formats (len=2)
                Type: ec_point_formats (11)
                Length: 2
                EC point formats Length: 1
                Elliptic curves point formats (1)
                    EC point format: uncompressed (0)
            Extension: signature_algorithms (len=46)
                Type: signature_algorithms (13)
                Length: 46
                Signature Hash Algorithms Length: 44
                Signature Hash Algorithms (22 algorithms)
                    Signature Algorithm: ed25519 (0x0807)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (7)
                    Signature Algorithm: ed448 (0x0808)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (8)
                    Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp384r1_sha384 (0x0503)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp521r1_sha512 (0x0603)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (4)
                    Signature Algorithm: rsa_pss_rsae_sha384 (0x0805)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (5)
                    Signature Algorithm: rsa_pss_rsae_sha512 (0x0806)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (6)
                    Signature Algorithm: rsa_pss_pss_sha256 (0x0809)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (9)
                    Signature Algorithm: rsa_pss_pss_sha384 (0x080a)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (10)
                    Signature Algorithm: rsa_pss_pss_sha512 (0x080b)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (11)
                    Signature Algorithm: rsa_pkcs1_sha256 (0x0401)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha384 (0x0501)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha512 (0x0601)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA256 DSA (0x0402)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA224 ECDSA (0x0303)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: SHA224 RSA (0x0301)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 DSA (0x0302)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: ecdsa_sha1 (0x0203)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: rsa_pkcs1_sha1 (0x0201)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA1 DSA (0x0202)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: MD5 RSA (0x0101)
                        Signature Hash Algorithm Hash: MD5 (1)
                        Signature Hash Algorithm Signature: RSA (1)
            Extension: signature_algorithms_cert (len=46)
                Type: signature_algorithms_cert (50)
                Length: 46
                Signature Hash Algorithms Length: 44
                Signature Hash Algorithms (22 algorithms)
                    Signature Algorithm: ed25519 (0x0807)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (7)
                    Signature Algorithm: ed448 (0x0808)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (8)
                    Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp384r1_sha384 (0x0503)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: ecdsa_secp521r1_sha512 (0x0603)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (4)
                    Signature Algorithm: rsa_pss_rsae_sha384 (0x0805)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (5)
                    Signature Algorithm: rsa_pss_rsae_sha512 (0x0806)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (6)
                    Signature Algorithm: rsa_pss_pss_sha256 (0x0809)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (9)
                    Signature Algorithm: rsa_pss_pss_sha384 (0x080a)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (10)
                    Signature Algorithm: rsa_pss_pss_sha512 (0x080b)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (11)
                    Signature Algorithm: rsa_pkcs1_sha256 (0x0401)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha384 (0x0501)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pkcs1_sha512 (0x0601)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA256 DSA (0x0402)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: SHA224 ECDSA (0x0303)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: SHA224 RSA (0x0301)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA224 DSA (0x0302)
                        Signature Hash Algorithm Hash: SHA224 (3)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: ecdsa_sha1 (0x0203)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: rsa_pkcs1_sha1 (0x0201)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: SHA1 DSA (0x0202)
                        Signature Hash Algorithm Hash: SHA1 (2)
                        Signature Hash Algorithm Signature: DSA (2)
                    Signature Algorithm: MD5 RSA (0x0101)
                        Signature Hash Algorithm Hash: MD5 (1)
                        Signature Hash Algorithm Signature: RSA (1)
            Extension: application_layer_protocol_negotiation (len=5)
                Type: application_layer_protocol_negotiation (16)
                Length: 5
                ALPN Extension Length: 3
                ALPN Protocol
                    ALPN string length: 2
                    ALPN Next Protocol: h2
            Extension: status_request_v2 (len=9)
                Type: status_request_v2 (17)
                Length: 9
                Certificate Status List Length: 7
                Certificate Status Type: OCSP Multi (2)
                Certificate Status Length: 4
                Responder ID list Length: 0
                Request Extensions Length: 0
            Extension: extended_master_secret (len=0)
                Type: extended_master_secret (23)
                Length: 0
            Extension: supported_versions (len=11)
                Type: supported_versions (43)
                Length: 11
                Supported Versions length: 10
                Supported Version: TLS 1.3 (0x0304)
                Supported Version: TLS 1.2 (0x0303)
                Supported Version: TLS 1.1 (0x0302)
                Supported Version: TLS 1.0 (0x0301)
                Supported Version: SSL 3.0 (0x0300)
            Extension: psk_key_exchange_modes (len=2)
                Type: psk_key_exchange_modes (45)
                Length: 2
                PSK Key Exchange Modes Length: 1
                PSK Key Exchange Mode: PSK with (EC)DHE key establishment (psk_dhe_ke) (1)
            Extension: key_share (len=71)
                Type: key_share (51)
                Length: 71
                Key Share extension

[](#Chrome "Chrome")[](#Chrome "Chrome")Chrome
----------------------------------------------

    TLSv1.2 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.0 (0x0301)
        Length: 512
        Handshake Protocol: Client Hello
            Handshake Type: Client Hello (1)
            Length: 508
            Version: TLS 1.2 (0x0303)
            Random: cda2b7713eda42ed5238959d5acbb8ffea6e9c7ae6bc541614761fc68ac1a7a0
                GMT Unix Time: Apr 29, 2079 19:24:33.000000000 CST
                Random Bytes: 3eda42ed5238959d5acbb8ffea6e9c7ae6bc541614761fc68ac1a7a0
            Session ID Length: 32
            Session ID: bfa5f956712d98ce593c9655df89762afed606a291145a70abbd12e17057376e
            Cipher Suites Length: 32
            Cipher Suites (16 suites)
                Cipher Suite: Reserved (GREASE) (0xeaea)
                Cipher Suite: TLS_AES_128_GCM_SHA256 (0x1301)
                Cipher Suite: TLS_AES_256_GCM_SHA384 (0x1302)
                Cipher Suite: TLS_CHACHA20_POLY1305_SHA256 (0x1303)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 (0xc02b)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (0xc02f)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 (0xc02c)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (0xc030)
                Cipher Suite: TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca9)
                Cipher Suite: TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca8)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA (0xc013)
                Cipher Suite: TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA (0xc014)
                Cipher Suite: TLS_RSA_WITH_AES_128_GCM_SHA256 (0x009c)
                Cipher Suite: TLS_RSA_WITH_AES_256_GCM_SHA384 (0x009d)
                Cipher Suite: TLS_RSA_WITH_AES_128_CBC_SHA (0x002f)
                Cipher Suite: TLS_RSA_WITH_AES_256_CBC_SHA (0x0035)
            Compression Methods Length: 1
            Compression Methods (1 method)
                Compression Method: null (0)
            Extensions Length: 403
            Extension: Reserved (GREASE) (len=0)
                Type: Reserved (GREASE) (27242)
                Length: 0
                Data: <MISSING>
            Extension: server_name (len=22)
                Type: server_name (0)
                Length: 22
                Server Name Indication extension
                    Server Name list length: 20
                    Server Name Type: host_name (0)
                    Server Name length: 17
                    Server Name: xxxx.xxxx.com
            Extension: extended_master_secret (len=0)
                Type: extended_master_secret (23)
                Length: 0
            Extension: renegotiation_info (len=1)
                Type: renegotiation_info (65281)
                Length: 1
                Renegotiation Info extension
                    Renegotiation info extension length: 0
            Extension: supported_groups (len=10)
                Type: supported_groups (10)
                Length: 10
                Supported Groups List Length: 8
                Supported Groups (4 groups)
            Extension: ec_point_formats (len=2)
                Type: ec_point_formats (11)
                Length: 2
                EC point formats Length: 1
                Elliptic curves point formats (1)
                    EC point format: uncompressed (0)
            Extension: session_ticket (len=0)
                Type: session_ticket (35)
                Length: 0
                Data (0 bytes)
            Extension: application_layer_protocol_negotiation (len=14)
                Type: application_layer_protocol_negotiation (16)
                Length: 14
                ALPN Extension Length: 12
                ALPN Protocol
                    ALPN string length: 2
                    ALPN Next Protocol: h2
                    ALPN string length: 8
                    ALPN Next Protocol: http/1.1
            Extension: status_request (len=5)
                Type: status_request (5)
                Length: 5
                Certificate Status Type: OCSP (1)
                Responder ID list Length: 0
                Request Extensions Length: 0
            Extension: signature_algorithms (len=18)
                Type: signature_algorithms (13)
                Length: 18
                Signature Hash Algorithms Length: 16
                Signature Hash Algorithms (8 algorithms)
                    Signature Algorithm: ecdsa_secp256r1_sha256 (0x0403)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: rsa_pss_rsae_sha256 (0x0804)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (4)
                    Signature Algorithm: rsa_pkcs1_sha256 (0x0401)
                        Signature Hash Algorithm Hash: SHA256 (4)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: ecdsa_secp384r1_sha384 (0x0503)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: ECDSA (3)
                    Signature Algorithm: rsa_pss_rsae_sha384 (0x0805)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (5)
                    Signature Algorithm: rsa_pkcs1_sha384 (0x0501)
                        Signature Hash Algorithm Hash: SHA384 (5)
                        Signature Hash Algorithm Signature: RSA (1)
                    Signature Algorithm: rsa_pss_rsae_sha512 (0x0806)
                        Signature Hash Algorithm Hash: Unknown (8)
                        Signature Hash Algorithm Signature: Unknown (6)
                    Signature Algorithm: rsa_pkcs1_sha512 (0x0601)
                        Signature Hash Algorithm Hash: SHA512 (6)
                        Signature Hash Algorithm Signature: RSA (1)
            Extension: signed_certificate_timestamp (len=0)
                Type: signed_certificate_timestamp (18)
                Length: 0
            Extension: key_share (len=43)
                Type: key_share (51)
                Length: 43
                Key Share extension
            Extension: psk_key_exchange_modes (len=2)
                Type: psk_key_exchange_modes (45)
                Length: 2
                PSK Key Exchange Modes Length: 1
                PSK Key Exchange Mode: PSK with (EC)DHE key establishment (psk_dhe_ke) (1)
            Extension: supported_versions (len=11)
                Type: supported_versions (43)
                Length: 11
                Supported Versions length: 10
                Supported Version: Unknown (0x4a4a)
                Supported Version: TLS 1.3 (0x0304)
                Supported Version: TLS 1.2 (0x0303)
                Supported Version: TLS 1.1 (0x0302)
                Supported Version: TLS 1.0 (0x0301)
            Extension: compress_certificate (len=3)
                Type: compress_certificate (27)
                Length: 3
                Algorithms Length: 2
                Algorithm: brotli (2)
            Extension: Reserved (GREASE) (len=1)
                Type: Reserved (GREASE) (31354)
                Length: 1
                Data: 00
            Extension: padding (len=203)
                Type: padding (21)
                Length: 203
                Padding Data: 000000000000000000000000000000000000000000000000000000000000000000000000…

对比一下burp和requests的Client Hello有什么区别

![image-20210417232659698](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/769e66829742d8050979c7beb9ae2867.png)

![image-20210418003345250](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/31a6dcc2a0e575f45cb0ed5c9d8df32e.png)

![image-20210418003434433](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/cbe6b119c2948f50df44b956fe3388c2.png)

一些不同的点：

Burp Suite

Requests

TLSv1.2 Record Layer: Handshake Protocol: Client Hello Version: TLS 1.2 (0x0303)

TLSv1.2 Record Layer: Handshake Protocol: Client Hello Version: TLS 1.0 (0x0301)

Length: 466

Length: 338

Cipher Suites Length: 104

Cipher Suites Length: 86

Cipher Suites (52 suites)

Cipher Suites (43 suites)

Cipher Suite: TLS\_AES\_128\_GCM\_SHA256 (0x1301) Cipher Suite:TLS\_AES\_256\_GCM\_SHA384 (0x1302) Cipher Suite: TLS\_ECDHE\_ECDSA\_WITH\_AES\_256\_GCM\_SHA384 (0xc02c)

Cipher Suite:TLS\_AES\_256\_GCM\_SHA384 (0x1302) Cipher Suite: TLS\_CHACHA20\_POLY1305\_SHA256 (0x1303) Cipher Suite: TLS\_AES\_128\_GCM\_SHA256 (0x1301)

Extensions Length: 285

Extensions Length: 175

Extension: signature\_algorithms (len=46)

Extension: signature\_algorithms (len=48)

Extension: supported\_versions (len=11)

Extension: supported\_versions (len=9)

可以看到很多地方都存在差异，主要为支持的协议，length，支持的加密套件，加密套件的排列方式等

多次请求可以发现相同的客户端发起请求，除了Random和Session ID之外其他内容是完全一样的

![image-20210418004913296](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/4b75b126c698d0f7851b6a9f739c4f5c.png)

所以这里面固定的内容其实就可以作为指纹来进行识别

比如加密套件`13 02`\-`00 ff`在tcp流当中就有固定的字节顺序

![image-20210418005437823](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/0a2f399e93195443529c97728ba9af6c.png)

[](#TLS-Fingerprint-识别原理 "TLS Fingerprint 识别原理")[](#TLS-Fingerprint-%E8%AF%86%E5%88%AB%E5%8E%9F%E7%90%86 "TLS Fingerprint 识别原理")TLS Fingerprint 识别原理
====================================================================================================================================================

[https://idea.popcount.org/2012-06-17-ssl-fingerprinting-for-p0f/](https://idea.popcount.org/2012-06-17-ssl-fingerprinting-for-p0f/)

[https://github.com/salesforce/ja3](https://github.com/salesforce/ja3)

看了下ja3 的指纹计算规则：

> The field order is as follows:
> 
>     SSLVersion,Cipher,SSLExtension,EllipticCurve,EllipticCurvePointFormat
> 
> Example:
> 
>     769,47-53-5-10-49161-49162-49171-49172-50-56-19-4,0-10-11,23-24-25,0

把版本，加密套件，扩展等内容按顺序排列然后计算hash值，便可得到一个客户端的TLS FingerPrint，waf防护规则其实就是整理提取一些常见的非浏览器客户端requests，curl的指纹然后在客户端发起https请求时进行识别并拦截

[](#Bypass "Bypass")[](#Bypass "Bypass")Bypass
==============================================

> 除了TLS指纹，对User-Agent也是有对应拦截，如果使用带有UA特征的客户端那么UA也是需要更改的

[](#1-访问ip指定host绕过waf "1.访问ip指定host绕过waf")[](#1-%E8%AE%BF%E9%97%AEip%E6%8C%87%E5%AE%9Ahost%E7%BB%95%E8%BF%87waf "1.访问ip指定host绕过waf")1.访问ip指定host绕过waf
-----------------------------------------------------------------------------------------------------------------------------------------------------

上文提到过，套了阿里云waf的服务器cname解析到了yundunwaf3.com的域名，这种情况可以直接ping 域名获取真实ip，然后请求地址设置为真实ip 在 HTTP Header的Host字段中指定域名即可绕过waf的防护

当然这种方式如果目标服务器开启了强制域名访问会失效

[](#2-代理中转请求 "2.代理中转请求")[](#2-%E4%BB%A3%E7%90%86%E4%B8%AD%E8%BD%AC%E8%AF%B7%E6%B1%82 "2.代理中转请求")2.代理中转请求
--------------------------------------------------------------------------------------------------------

在本地启动代理服务器，如Burp Suite，发起http请求时指定代理服务器为burp的地址，让burp来进行TLS握手，算是一种曲线救国的方法

    import requests
    proxies = {
    'http': 'http://127.0.0.1:8080',
    'https': 'http://127.0.0.1:8080'
    }
    rsp=requests.get(url,proxies=proxies)

当然这种方案需要找一个不会被拦截的客户端代理才可以，试了几个go写的代理如goproxy发现仍然被拦截

[](#3-更换request工具库 "3.更换request工具库")[](#3-%E6%9B%B4%E6%8D%A2request%E5%B7%A5%E5%85%B7%E5%BA%93 "3.更换request工具库")3.更换request工具库
------------------------------------------------------------------------------------------------------------------------------

Requests其实是对urllib3的一个封装，那python有没有不用urllib的http request库呢？

翻了翻aiohttp的源码发现貌似并没有用urllib3，抓包发现tls指纹和requests也有着明显的差异

实际测试aiohttp确实没有被拦截

[](#4-魔改requests "4.魔改requests")[](#4-%E9%AD%94%E6%94%B9requests "4.魔改requests")4.魔改requests
--------------------------------------------------------------------------------------------

从根本上解决问题，debug跟踪到了几处可能可以修改TLS握手特征的代码

举一个🌰

`/usr/local/lib/python3.9/site-packages/urllib3/util/ssl_.py`

    DEFAULT_CIPHERS = ":".join(
        [
            "ECDHE+AESGCM",
            "ECDHE+CHACHA20",
            "DHE+AESGCM",
            "DHE+CHACHA20",
            "ECDH+AESGCM",
            "DH+AESGCM",
            "ECDH+AES",
            "DH+AES",
            "RSA+AESGCM",
            "RSA+AES",
            "!aNULL",
            "!eNULL",
            "!MD5",
            "!DSS",
        ]
    )

`DEFAULT_CIPHERS`中定义了一部分的加密套件，直接进行一个删除

> 当然其他能改的地方还有很多

![image-20210418013151683](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/9b194c9cc7714f219fd714d0856e3e26.png)

成功绕过了阿里云的拦截

![image-20210418012703824](/images/SSL-%E6%8C%87%E7%BA%B9%E8%AF%86%E5%88%AB%E5%92%8C%E7%BB%95%E8%BF%87/d4667e7b609a6caf7b7c6961e77e4d66.png)

原本内容:

    Cipher Suites Length: 86
    Cipher Suites (43 suites)

修改后的内容：

    Cipher Suites Length: 80
    Cipher Suites (40 suites)

加密套件的内容发生了变化，使得Finger Print和原本requests不一致

理论上其他客户端也可以进行修改代码实现变更TLS指纹的操作，但是如java,go等编译型语言写的工具在没有源码的情况下修改会很麻烦

[](#Other "Other")[](#Other "Other")Other
=========================================

感觉是好多年前就被研究出来的技术了，一定程度上来说确实能防止一些特定语言和客户端的爬虫和扫描工具，尤其是脚本小子们，未来各家waf防火墙估计也会上对应的功能，虽然目前只在阿里云waf见过，目前其他家waf的防爬虫功能貌似就是没啥卵用的识别个User-Agent

作为一个Scripting Kiddie日个站已经很不容易了,总搞这种影响体验的东西搞👴的心态真的好🐎？

全版本burp的指纹麻烦加一加，大家都不用上班了，美滋滋（之前有几次发现某些站只要挂了burp就无法访问但是同事其他版本的burp屁事没有，现在想起来可能也是这个问题

本博客采用 [知识共享署名-非商业性使用-相同方式共享 4.0 国际许可协议(CC BY-NC-SA 4.0) 发布.](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)

_Page View_

Prev [Home](/) [Next](/2021/04/14/HTB-You-know-0xDiablos/)

import { init } from 'https://unpkg.com/@waline/client@v2/dist/waline.mjs'; var walineConfig = {"enable":true,"serverURL":"https://waline.ares-x.com","pageview":true,"lang":"en","dark":true,"requiredMeta":\["nick","mail"\],"locale":{"placeholder":"Comment with Email address will get notification when replied"}} walineConfig.el='#waline'; init(walineConfig);

2021-04-18

*   [渗透不测试27](/categories/渗透不测试/)

*   [渗透不测试2](/tags/渗透不测试/)
*   [SSL1](/tags/SSL/)
*   [TLS1](/tags/TLS/)
*   [Bypass1](/tags/Bypass/)

Contents

1.  [SSL Fingerprint and Bypass](#SSL-Fingerprint-and-Bypass)
2.  [Python 403 Burp 200?](#Python-403-Burp-200)
    1.  [Burp](#Burp)
    2.  [Python3 Requests](#Python3-Requests)
3.  [不同客户端的ClientHello报文](#%E4%B8%8D%E5%90%8C%E5%AE%A2%E6%88%B7%E7%AB%AF%E7%9A%84ClientHello%E6%8A%A5%E6%96%87)
    1.  [CURL ClientHello](#CURL-ClientHello)
    2.  [Python3 Requests](#Python3-Requests-1)
    3.  [Python3 aioHTTP](#Python3-aioHTTP)
    4.  [Burp Suite](#Burp-Suite)
    5.  [Chrome](#Chrome)
4.  [TLS Fingerprint 识别原理](#TLS-Fingerprint-%E8%AF%86%E5%88%AB%E5%8E%9F%E7%90%86)
5.  [Bypass](#Bypass)
    1.  [1.访问ip指定host绕过waf](#1-%E8%AE%BF%E9%97%AEip%E6%8C%87%E5%AE%9Ahost%E7%BB%95%E8%BF%87waf)
    2.  [2.代理中转请求](#2-%E4%BB%A3%E7%90%86%E4%B8%AD%E8%BD%AC%E8%AF%B7%E6%B1%82)
    3.  [3.更换request工具库](#3-%E6%9B%B4%E6%8D%A2request%E5%B7%A5%E5%85%B7%E5%BA%93)
    4.  [4.魔改requests](#4-%E9%AD%94%E6%94%B9requests)
6.  [Other](#Other)

* * *