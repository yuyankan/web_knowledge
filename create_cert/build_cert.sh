#!/bin/bash

openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt -days 365 -nodes

: '
命令详解：

req: 这条命令用于处理证书签名请求。

-x509: 这个参数非常关键。它告诉 OpenSSL 我们要创建一个 自签名的 X.509 证书，而不是一个 CSR。这直接跳过了向 CA 申请的步骤。

-newkey rsa:2048: 生成一个新的 RSA 密钥对，密钥长度为 2048 位。

-keyout server.key: 指定生成的私钥文件名为 server.key。

-out server.crt: 指定生成的证书文件名为 server.crt。

-days 365: 设置证书的有效期为 365 天。

-nodes: 这表示不加密私钥（no des）。如果你不加这个参数，系统会要求你输入一个密码来保护私钥，每次启动 Nginx 时都需要输入密码，这对于自动化很不方便。

当你运行这条命令时，它会像之前一样要求你输入一些信息，比如国家、城市、和Common Name（域名）。输入完毕后，server.key 和 server.crt 这两个文件就会直接生成。'
