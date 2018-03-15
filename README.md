# ssl-certs-self-sign
SSL证书自签名bash脚本

生成nginx下使用的，自签名通配符域名证书。

## Usage

```
bash ./self-sign.sh
```

生成的证书目录为certs_signed，该目录下有nginx.conf，可供其它vhost.conf引用

```
# cat vhost.conf

server {
	server_name www.example.com;
	listen 443 ssl;
	include /tmp/ssl-certs-self-sign/nginx.conf;

	location / {
		return 200 "<html><head></head><body>Hello World</body></html>";
	}
}
```
