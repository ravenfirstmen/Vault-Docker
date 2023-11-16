#!/bin/bash

CA_NAME=$1
OUTPUT_FOLDER=$2

openssl genrsa -out ${OUTPUT_FOLDER}/${CA_NAME}-key.pem 4096

openssl req -x509 -new -nodes -key ${OUTPUT_FOLDER}/${CA_NAME}-key.pem -sha256 -days 1826 -out ${OUTPUT_FOLDER}/${CA_NAME}.pem -subj "/CN=${CA_NAME}/C=PT/ST=Braga/L=Famalicao/O=Casa"
