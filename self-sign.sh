#! /bin/bash

# vars: begin
CERTS_DIR="certs_signed"
CA_DIR="ca"

FILENAME_DOMAIN_CERT="cert.crt"
FILENAME_DOMAIN_CERT_FULLCHAIN="fullchain.crt"

FILENAME_DOMAIN_KEY="domain.key"
FILENAME_DOMAIN_CSR="domain.csr"

FILENAME_CA_KEY="ca.key"
FILENAME_CA_CERT="ca.crt"

FILENAME_EXTEND_TEMPLATE="extended.ext.template"
FILENAME_OPENSSL_TEMPLATE="openssl.cnf"

FILENAME_DEMOCA_TAR="demoCA.tar.gz"
FILENAME_DEMOCA_DIR="demoCA"

FILENAME_NGINX_CONF="nginx.conf"
# vars: end

function generate_a_CA(){
	echo "--------- generate a CA ---------"
	
	echo -n "input the name of CA: "
	read input_str;
	
	CommonName="example.com"
	if [ ! "x" = "x$input_str" ]; then
		CommonName=$input_str
	fi
	
	mkdir -p $CA_DIR
	rm -rf $CA_DIR/*
	
	openssl ecparam -genkey -name prime256v1 -out $CA_DIR/$FILENAME_CA_KEY

	openssl req -new -x509 -days 7305 -key $CA_DIR/$FILENAME_CA_KEY -out $CA_DIR/$FILENAME_CA_CERT \
	  -subj "/C=CN/ST=BJ/L=BJ/CN=$CommonName"
	
	echo ""
}

# param $1: domain_name
function sign(){
	echo "------ sign a wildcard cert ------"
	
	if [ "x" = "x$1" ]; then
		echo "sign error: domain is empty"
		exit 1
	fi
	
	domain=$1
	
	rm -rf $FILENAME_DEMOCA_DIR
	tar xf $FILENAME_DEMOCA_TAR
	
	filename_extend="extended.ext"
	
	cat $FILENAME_EXTEND_TEMPLATE > $filename_extend
	echo "" >> $filename_extend
	echo "subjectAltName = DNS:$domain,DNS:*.$domain" >> $filename_extend
	
	openssl x509 -req \
	  -days 7305 \
	  -sha256 \
	  -CA $CA_DIR/$FILENAME_CA_CERT -CAkey $CA_DIR/$FILENAME_CA_KEY -CAcreateserial \
	  -in $CERTS_DIR/$domain/$FILENAME_DOMAIN_CSR -out $CERTS_DIR/$domain/$FILENAME_DOMAIN_CERT \
	  -extfile $filename_extend -extensions SAN
	
	cat $CERTS_DIR/$domain/$FILENAME_DOMAIN_CERT $CA_DIR/$FILENAME_CA_CERT > $CERTS_DIR/$domain/$FILENAME_DOMAIN_CERT_FULLCHAIN
	
	echo ""
	echo "-------nginx config example-------"
	echo "filename = $CERTS_DIR/$domain/$FILENAME_NGINX_CONF"
	
	echo "# $domain" > $CERTS_DIR/$domain/$FILENAME_NGINX_CONF
	echo "ssl_certificate $PWD/$CERTS_DIR/$domain/$FILENAME_DOMAIN_CERT;" >> $CERTS_DIR/$domain/$FILENAME_NGINX_CONF
	echo "ssl_certificate_key $PWD/$CERTS_DIR/$domain/$FILENAME_DOMAIN_KEY;" >> $CERTS_DIR/$domain/$FILENAME_NGINX_CONF
	echo "ssl_trusted_certificate $PWD/$CERTS_DIR/$domain/$FILENAME_DOMAIN_CERT_FULLCHAIN;" >> $CERTS_DIR/$domain/$FILENAME_NGINX_CONF
}

# param $1: domain_name
function generate_a_domain_csr_and_sign(){
	echo "------- domain CSR ----------------"
	
	echo -n "input the domain: "
	read input_str;
	
	domain="example.com"
	if [ ! "x" = "x$input_str" ]; then
		domain=$input_str
	fi
	
	mkdir -p $CERTS_DIR/$domain
	rm -rf $CERTS_DIR/$domain/*
	
	openssl ecparam -genkey -name prime256v1 -out $CERTS_DIR/$domain/$FILENAME_DOMAIN_KEY
	
	openssl req -new -sha256 \
	  -key $CERTS_DIR/$domain/$FILENAME_DOMAIN_KEY -out $CERTS_DIR/$domain/$FILENAME_DOMAIN_CSR\
	  -subj "/C=CN/ST=BJ/L=BJ/CN=$domain"
	
	echo ""
	
	sign $domain
}

echo "1 for sign a wildcard cert using an new CA"
echo "2 for sign a wildcard cert using an exist CA"
echo -n "input a num: "
read choose

case $choose in
	"1")
		generate_a_CA
		generate_a_domain_csr_and_sign
		;;
	"2")
		generate_a_domain_csr_and_sign
		;;
	*)
		echo "invalid input"
		exit 1
		;;
esac