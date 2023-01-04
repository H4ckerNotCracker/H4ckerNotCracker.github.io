---
title: PHP是如何解析JSON的
date: 2019-10-17 02:25:00
tags:
---

 [PHP是如何解析JSON的](/2019/04/06/how_does_php_parse_json.html)

[php](/tags/php/)

[json](/tags/json/)

[debug](/tags/debug/)

 2019-04-06 20:16:19

Info
----

`json_decode ( string $json [, bool $assoc = false [, int $depth = 512 [, int $options = 0 ]]] ) : mixed`

(PHP 5 >= 5.2.0, PHP 7, PECL json >= 1.2.0)  
json\_decode — 对 JSON 格式的字符串进行解码

参数

说明

json

待解码的 json string 格式的字符串。（RFC 7159）

assoc

当该参数为 TRUE 时，将返回 array 而非 object。

depth

指定递归深度。

options

JSON解码的掩码选项。 现在有两个支持的选项。

JSON\_BIGINT\_AS\_STRING，大整数转为字符串（默认float类型）。

JSON\_OBJECT\_AS\_ARRAY，与将assoc设置为 TRUE 有相同的效果。

变化
--

*   自 PHP 5.2.0 起，JSON 扩展默认内置并编译进了 PHP。
*   [PHP 5 JSON\_checker - Douglas Crockford](http://www.json.org/JSON_checker/)
    *   a Pushdown Automaton that very quickly determines.
*   PHP 7 中是改进的全新解析器，专门为 PHP 订制，软件许可证为 PHP license。
    *   re2c 0.16
    *   Bison 3.0.4

PHP 版本说明
--------

*   **PHP 5** [5.6.40](https://www.php.net/distributions/php-5.6.40.tar.gz)
*   **PHP 7** [7.3.4](https://www.php.net/distributions/php-7.3.4.tar.gz)

PHP 5 : Call Stack of json\_decode (zif\_json\_decode)
------------------------------------------------------

毕竟5已经停止更新了，就简单提及一下

*   **zif\_json\_decode** _ext/json/json.c:831-857_
    *   **php\_json\_decode\_ex** _ext/json/json.c:680-796_
        *   **json\_utf8\_to\_utf16** utf8 转 utf16
        *   **new\_JSON\_parser** 初始化
        *   **parse\_JSON\_ex** 解析 **ext/json/JSON\_parser.c:439-750**

JSON\_parser.c 就是 JSON\_checker 的

PHP 7 : Call Stack of json\_decode (zif\_json\_decode)
------------------------------------------------------

### zif\_json\_decode

**ext/json/json.c:312-362**

默认嵌套深度 ：`depth = PHP_JSON_PARSER_DEFAULT_DEPTH (= 512 [php_json.h])`  
最大嵌套深度 ：`depth > INT_MAX (= 2147483647 [php.h])`

接受参数并调用`php_json_decode_ex`

### php\_json\_decode\_ex

**ext/json/json.c:246-264**

1.  初始化 PHP 的`json`解析器 `php_json_parser_init`
2.  解析 json 字符串 `php_json_yyparse`
3.  如果解析错误，抛出异常及错误信息
4.  返回 PHP Object

### php\_json\_yyparse (yyparse)

**ext/json/json\_parser.tab.c:115**

`#define yyparse php_json_yyparse`

**ext/json/json\_parser.tab.c:1194-843**

`int yyparse(php_json_parser *parser)`

    // L:1359
    if (yychar == YYEMPTY)
      {
        YYDPRINTF((stderr, "Reading a token: "));
        yychar = yylex(&yylval, parser);
      }
    

### yylex (php\_json\_yylex)

**ext/json/json\_parser.tab.c:116**

`#define yylex php_json_yylex`

**ext/json/json\_parser.tab.c:1899-1904**

    static int php_json_yylex(union YYSTYPE *value, php_json_parser *parser)
    {
      int token = php_json_scan(&parser->scanner);
      value->value = parser->scanner.value;
      return token;
    }
    

### php\_json\_scan

**ext/json/json\_scanner.c:106-end**

匹配并解析字符串（包括\\uXXXX,\\r等）

### Flowchart

![](https://xzfile.aliyuncs.com/media/upload/picture/20190408011455-aa2351d0-5958-1.png)

Example Parser Unicode(\\u003e)
-------------------------------

### Source Code json.php

    <?php
    print_r("===== Unicode \\u003e ===== ");
    $str = '{"vk":"vir\u003eink"}';
    $obj = json_decode($str);
    print_r($str . "\r\n");
    print_r($obj);
    /* Output
    ===== Unicode \u003e ===== 
    {"vk":"vir\u003eink"}
    stdClass Object
    (
        [vk] => vir>ink
    )
    */
    

[完整文件 - PHP是如何解析JSON的 - 测试文件 - Gist](https://gist.github.com/8d2d8677156f6abde3beba2fa9b13a1f#file-php_debug_example_json-php)

### Call Stack

#### 进入解析

1.  php\_json\_scan (ext/json/json\_scanner.c)

#### JSON字符 匹配 value “\\u003e”

1.  省略 vir…
2.  `if (yych <= '\\') goto yy77; (L:553) // \`
3.  `if (yych <= 'u') goto yy90; (L:625) // u`
4.  `if (yych <= '0') goto yy94; (L:706) // 0`
5.  `if (yych <= '0') goto yy97; (L:747) // 0`
6.  `if (yych <= '7') goto yy102; (L:797) // 3`
7.  `if (yych <= 'f') goto yy107; (L:863) // e`
8.  `s->str_esc += 5; (L:917) // \u003e -> >`
9.  `size_t len = s->cursor - s->str_start - s->str_esc - 1 + s->utf8_invalid_count; (L:583) // 长度处理`
10.  省略ink

![](media/15545529793878/15546570791335.jpg)

#### Unicode匹配并解析（\\u003e）

1.  `if (yych == '\\') goto yy175; (L:1369) // \`
2.  `if (yych == 'u') goto yy177; (L:1381) // u`
3.  `if (yych <= '0') goto yy179; (L:1420) // 0`
4.  `if (yych <= '0') goto yy182; (L:1443) // 0`
5.  `if (yych <= '7') goto yy186; (L:1485) // 3`
6.  `if (yych <= 'f') goto yy190; (L:1539) // e`

#### 转换 Unicode 为 Char

1.  `int utf16 = php_json_ucs2_to_int(s, 2); (L:1581->92)`
2.  `return php_json_ucs2_to_int_ex(s, size, 1); (L:94) // return 62`

![](media/15545529793878/15546566919786.jpg)

从静态到动态
------

### 静态分析

**代码阅读工具**

*   Sublime Text 3
*   Visual Studio Code
    *   ext: Lex Flex Yacc Bison
*   Understand

**分析**

*   目标 : JSON 扩展
*   目录 : `ext/json/`
*   文件 : `ext/json/json.c`
*   函数 : `static PHP_FUNCTION(json_decode)`

函数名称都比较容易看懂，编辑器大多数都有**转到定义**功能

*   php\_json\_decode\_ex
    *   php\_json\_parser\_init
    *   php\_json\_yyparse
    *   …etc

上文(**PHP 7 : Call Stack of json\_decode** )列的也比较详细了

一个字就是**看**

`ext/json/README`也是要先看看的

    The parser is implemented using re2c and Bison. The used versions
    of both tools for generating files in the repository are following:
    
    re2c 0.16
    Bison 3.0.4
    

当然，后缀为`*.y`和`*.re`的文件也说明了这个解析涉及**扫描程序(scanner)**和**语法分析(parser)**。

PS. 编译原理。。。反正我不懂

### 动态分析

通过静态分析，我们可以得到一些关键函数

*   php\_json\_decode\_ex
*   php\_json\_yyparse
*   yylex
*   **php\_json\_scan**

给**php\_json\_scan**下断点，单步进入一把唆，调试过程中随时加断点

*   php\_json\_scan
*   std: (ext/json/json\_parser.tab.c:115)
*   yyc\_JS: (ext/json/json\_parser.tab.c:167)
*   yyc\_STR\_P1: (ext/json/json\_parser.tab.c:547)
*   php\_json\_ucs2\_to\_int\_ex
*   php\_json\_hex\_to\_int

PS. **单步跳过**有点坑，尽可能用**单步调试**和**单步跳出**

转载声明
----

本文首发于先知社区：[PHP是如何解析JSON的 - https://xz.aliyun.com/t/4719](https://xz.aliyun.com/t/4719)

