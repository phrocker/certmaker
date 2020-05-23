#!/bin/bash 
ROOT_CA_HOME=$1
INTERMEDIATE_NAME=$2
CERT_CN_NAME=$3
INTERMEDIATE=${INTERMEDIATE_NAME}-home
CERT_LOC=${CERT_CN_NAME}-keypair

FULLPATH=${ROOT_CA_HOME}/${INTERMEDIATE}

source .myroot
function usage {
    echo "usage: make_ca.sh <root CA path> <intermediate CA name> <your cert CN name>"
    exit
}

if [ -z "$ROOT_CA_HOME" ] || [ -z "$INTERMEDIATE_NAME" ] || [ -z "$CERT_CN_NAME" ]; then
    usage
fi

mkdir ${CERT_LOC} 2>/dev/null

echo "Created ${CERT_LOC}/ to store your key pair..."

openssl genrsa -aes256 \
      -out ${CERT_LOC}/${CERT_CN_NAME}.key.pem 2048
chmod 400 ${CERT_LOC}/${CERT_CN_NAME}.key.pem

openssl req -config ${FULLPATH}/openssl.cnf \
      -key ${CERT_LOC}/${CERT_CN_NAME}.key.pem \
      -new -sha256 -out ${CERT_LOC}/${CERT_CN_NAME}.csr.pem

openssl ca -config ${FULLPATH}/openssl.cnf \
      -extensions usr_cert -days 375 -notext -md sha256 \
      -in ${CERT_LOC}/${CERT_CN_NAME}.csr.pem \
      -out ${CERT_LOC}/${CERT_CN_NAME}.cert.pem

chmod 444 ${CERT_LOC}/${CERT_CN_NAME}.cert.pem
rm ${CERT_LOC}/${CERT_CN_NAME}.csr.pem
echo "Your Certificate is located at ${CERT_LOC}/${CERT_CN_NAME}.cert.pem"
echo "Your private key is located at ${CERT_LOC}/${CERT_CN_NAME}.key.pem, please protect it"
