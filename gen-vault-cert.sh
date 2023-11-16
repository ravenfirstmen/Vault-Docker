#!/bin/bash

if [ "$#" -ne 4 ]
then
  echo "Usage: Must supply a domain, the ca and output folder"
  exit 1
fi

CA_NAME=$1
DOMAIN=$2
IP=$3
OUTPUT_FOLDER=$4

openssl genrsa -out ${OUTPUT_FOLDER}/${DOMAIN}-key.pem 4096
openssl req -new -key ${OUTPUT_FOLDER}/${DOMAIN}-key.pem -out ${OUTPUT_FOLDER}/${DOMAIN}.csr -subj "/CN=${DOMAIN}/C=PT/ST=Braga/L=Famalicao/O=Casa"

cat > ${OUTPUT_FOLDER}/${DOMAIN}.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${DOMAIN}
IP.1 = 127.0.0.1
IP.2 = ${IP}
EOF

openssl x509 -req -in ${OUTPUT_FOLDER}/${DOMAIN}.csr -CA ${OUTPUT_FOLDER}/${CA_NAME}.pem -CAkey ${OUTPUT_FOLDER}/${CA_NAME}-key.pem -CAcreateserial -out ${OUTPUT_FOLDER}/${DOMAIN}.pem -days 825 -sha256 -extfile ${OUTPUT_FOLDER}/${DOMAIN}.ext 