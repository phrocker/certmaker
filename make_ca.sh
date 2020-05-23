#!/bin/bash 
ROOT_CA_HOME=$1
INTERMEDIATE_NAME=$2
INTERMEDIATE=${INTERMEDIATE_NAME}-home

FULLPATH=${ROOT_CA_HOME}/${INTERMEDIATE}

function usage {
    echo "usage: make_ca.sh <root CA path> <intermediate CA name>"
    exit
}

if [ -z "$ROOT_CA_HOME"] || [ -z "$INTERMEDIATE_NAME"] ; then
    usage
fi
mkdir ${FULLPATH}
cd ${FULLPATH}
rm -rf certs crl csr newcerts private
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > crlnumber

cat >> openssl.cnf <<EOL
[ ca ]
# man ca
default_ca = IntCA

[ IntCA ]
# Directory and file locations.
dir               = ${ROOT_CA_HOME}
private_key     = $dir/private/${INTERMEDIATE_NAME}.key.pem
certificate     = $dir/certs/${INTERMEDIATE_NAME}.cert.pem
crl             = $dir/crl/${INTERMEDIATE_NAME}.crl.pem
policy          = policy_loose

# The root key and root certificate.
private_key       = ${ROOT_CA_HOME}/private/ca.key.pem
certificate       = ${ROOT_CA_HOME}/certs/ca.cert.pem

# For certificate revocation lists.
crlnumber         = ${ROOT_CA_HOME}/crlnumber
crl               = ${ROOT_CA_HOME}/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_strict
[ policy_strict ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of man ca.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
[ policy_loose ]
# Allow the intermediate CA to sign a more diverse range of certificates.
# See the POLICY FORMAT section of the ca man page.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional
[ req ]
# Options for the req tool (man req).
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca
[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = US
stateOrProvinceName_default     = ${STATE}
localityName_default            =
0.organizationName_default      = ${ORG}
#organizationalUnitName_default =
#emailAddress_default           =

[ v3_ca ]
# Extensions for a typical CA (man x509v3_config).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions for a typical intermediate CA (man x509v3_config).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ usr_cert ]
# Extensions for client certificates (man x509v3_config).
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate for ${ORG}"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ server_cert ]
# Extensions for server certificates (man x509v3_config).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate for ${ORG}"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ crl_ext ]
# Extension for CRLs (man x509v3_config).
authorityKeyIdentifier=keyid:always

[ ocsp ]
# Extension for OCSP signing certificates (man ocsp).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOL
cd ${ROOT_CA_HOME}

echo "Creating ${INTERMEDIATE_NAME}'s Key..."
openssl genrsa -aes256 \
      -out ${INTERMEDIATE}/private/${INTERMEDIATE_NAME}.key.pem 4096

chmod 400  ${INTERMEDIATE}/private/${INTERMEDIATE_NAME}.key.pem

echo "Creating ${INTERMEDIATE_NAME}'s certificate..."

openssl req -config ${INTERMEDIATE}/openssl.cnf -new -sha256 \
      -key ${INTERMEDIATE}/private/${INTERMEDIATE_NAME}.key.pem \
      -out ${INTERMEDIATE}/csr/${INTERMEDIATE_NAME}.csr.pem

openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in ${INTERMEDIATE}/csr/${INTERMEDIATE_NAME}.csr.pem \
      -out ${INTERMEDIATE}/certs/${INTERMEDIATE_NAME}.cert.pem

chmod 444 ${INTERMEDIATE}/certs/${INTERMEDIATE_NAME}.cert.pem

echo "Verifying ${INTERMEDIATE_NAME}'s certificate..."

openssl x509 -noout -text \
      -in ${INTERMEDIATE}/certs/${INTERMEDIATE_NAME}.cert.pem

openssl verify -CAfile certs/ca.cert.pem \
     ${INTERMEDIATE}/certs/${INTERMEDIATE_NAME}.cert.pem

echo "Creating certificate chain..."

cat ${INTERMEDIATE}/certs/${INTERMEDIATE_NAME}.cert.pem \
      certs/ca.cert.pem > ${INTERMEDIATE}/certs/ca-chain.cert.pem


echo "Your CA certificate is located at ${INTERMEDIATE}/certs/${INTERMEDIATE_NAME}.cert.pem"
echo "Your CA certificate chain is located at ${INTERMEDIATE}/certs/ca-chain.cert.pem"

echo "The process is complete. If you have no more CAs to generate, please take your Root key offline..."