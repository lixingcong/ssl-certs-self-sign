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

DOMAIN_SPLIT_CHAR=";"
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

# param $1: domain_name array
function sign(){
	echo "------ sign a wildcard cert ------"
	
	RESULT_ARRAY=$1
	
	# get length of an array
	ARRAY_LEN=${#RESULT_ARRAY[@]}

	SAN_ARGS=""
	for (( i=0; i<${ARRAY_LEN}; i++ )); do
		if [[ ${RESULT_ARRAY[$i]} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
			SAN_ARGS+="IP:${RESULT_ARRAY[$i]}"
		else
			SAN_ARGS+="DNS:${RESULT_ARRAY[$i]}"
		fi
		
		if (( i < ARRAY_LEN-1 )); then
			SAN_ARGS+=","
		fi
	done
	
	domain=${RESULT_ARRAY[0]}
	
	rm -rf $FILENAME_DEMOCA_DIR
	tar xf $FILENAME_DEMOCA_TAR
	
	filename_extend="extended.ext"
	
	cat $FILENAME_EXTEND_TEMPLATE > $filename_extend
	echo "" >> $filename_extend
	echo "subjectAltName = $SAN_ARGS" >> $filename_extend
	
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
	
	echo "input all domains(splited by $DOMAIN_SPLIT_CHAR)"
	echo "the first domain was the COMMON NAME"
	echo "for example, abc.com;*.abc.com;*.xyz.com is ok"
	echo  -n "input here: "
	read input_str;
	
	declare -a RESULT_ARRAY
	if [ ! "x" = "x$input_str" ]; then
		IFS=$DOMAIN_SPLIT_CHAR read -a RESULT_ARRAY <<< "$input_str"
	else
		echo "input was empty, exit."
		exit 1
	fi
	
	domain=${RESULT_ARRAY[0]}
	
	mkdir -p $CERTS_DIR/$domain
	rm -rf $CERTS_DIR/$domain/*
	
	openssl ecparam -genkey -name prime256v1 -out $CERTS_DIR/$domain/$FILENAME_DOMAIN_KEY
	
	openssl req -new -sha256 \
	  -key $CERTS_DIR/$domain/$FILENAME_DOMAIN_KEY -out $CERTS_DIR/$domain/$FILENAME_DOMAIN_CSR\
	  -subj "/C=CN/ST=BJ/L=BJ/CN=${RESULT_ARRAY[0]}"
	
	echo ""
	
	sign $RESULT_ARRAY
}

echo "1 for generate a new CA"
echo "2 for sign a wildcard cert using an exist CA"
#echo "3 for sign cert from CSR using an exist CA" # TODO: modify extended.ext and import CSR
echo -n "input a num: "
read choose

case $choose in
	"1")
		generate_a_CA
		;;
	"2")
		generate_a_domain_csr_and_sign
		;;
	*)
		echo "invalid input"
		exit 1
		;;
esac
