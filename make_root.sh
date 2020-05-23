#!/bin/bash 
ROOT_CA_HOME=$1
STATE=$2
ORG=$3

echo "STATE=${STATE}"> ".myroot"
echo "ORG=${ORG}">> ".myroot"
function usage {
    echo "usage: make_root.sh <root CA path> <state> <org>"
    exit
}

if [ -z "$ORG" ] || [ -z "$STATE"] || [ -z "$ROOT_CA_HOME"] ; then
    usage
fi
mkdir ${ROOT_CA_HOME}
cd ${ROOT_CA_HOME}
rm -rf certs crl newcerts private
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial

cat >> openssl.cnf <<EOL
[ ca ]
# man ca
default_ca = RootCA

[ RootCA ]
# Directory and file locations.
dir               = ${ROOT_CA_HOME}
certs             = ${ROOT_CA_HOME}/certs
crl_dir           = ${ROOT_CA_HOME}/crl
new_certs_dir     = ${ROOT_CA_HOME}/newcerts
database          = ${ROOT_CA_HOME}/index.txt
serial            = ${ROOT_CA_HOME}/serial
RANDFILE          = ${ROOT_CA_HOME}/private/.rand

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

echo "Generating Root Key..."
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

echo "Genearting Root Certificate..."
openssl req -config openssl.cnf \
      -key private/ca.key.pem \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out certs/ca.cert.pem

chmod 444 certs/ca.cert.pem

echo "Verifying root certificate..."

chmod 444 certs/ca.cert.pem

echo "Process is now complete. Please take the root key offline after generating a CA with make_ca..."
