#!/bin/sh
# allin-tsa.sh - 1.1
#
# Generic script using curl to invoke Swisscom Allin service: TSA
# Dependencies: curl, openssl, base64, sed, date, xmllint, tr, python
#
# Change Log:
#  1.0 26.11.2013: Initial version
#  1.1 04.12.2013: Added support for RESTful interface

######################################################################
# User configurable options
######################################################################

# AP_ID used to identify to Allin (provided by Swisscom)
AP_ID=cartel.ch

######################################################################
# There should be no need to change anything below
######################################################################

# Error function
error()
{
  [ "$VERBOSE" = "1" -o "$DEBUG" = "1" ] && echo "$@" >&2
  exit 1                                        
}

# Check command line
MSGTYPE=SOAP                                    # Default is SOAP
DEBUG=
VERBOSE=
while getopts "dvt:" opt; do
  case $opt in
    t) MSGTYPE=$OPTARG ;;
    d) DEBUG=1 ;;
    v) VERBOSE=1 ;; 
  esac
done

shift $((OPTIND-1))                             # Remove the options

if [ $# -lt 3 ]; then                           # Parse the rest of the arguments
  echo "Usage: $0 <args> digest method pkcs7"
  echo "  -t value  - message type (SOAP, XML, JSON), default SOAP"
  echo "  -v        - verbose output"
  echo "  -d        - debug mode"
  echo "  digest    - digest/hash to be signed"
  echo "  method    - digest method (SHA224, SHA256, SHA384, SHA512)"
  echo "  pkcs7     - output file with PKCS#7 (Crytographic Message Syntax)"
  echo
  echo "  Examples $0 GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s"
  echo "           $0 -t JSON -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s"
  echo 
  exit 1
fi

PWD=$(dirname $0)                               # Get the Path of the script

# Check the dependencies
for cmd in curl openssl base64 sed date xmllint tr python; do
  hash $cmd &> /dev/null
  if [ $? -eq 1 ]; then error "Dependency error: '$cmd' not found" ; fi
done

# Swisscom Mobile ID credentials
CERT_FILE=$PWD/mycert.crt                       # The certificate that is allowed to access the service
CERT_KEY=$PWD/mycert.key                        # The related key of the certificate

# Swisscom SDCS elements
SSL_CA=$PWD/allin-ssl.crt                       # Bag file for SSL server connection

# Create temporary request
INSTANT=$(date +%Y-%m-%dT%H:%M:%S.%N%:z)        # Define instant and request id
REQUESTID=ALLIN.TEST.$INSTANT
REQ=$(mktemp /tmp/_tmp.XXXXXX)                  # Request goes here
TIMEOUT_CON=90                                  # Timeout of the client connection

# Hash and digests
DIGEST_VALUE=$1                                 # Hash to be signed
DIGEST_METHOD=$2                                # Digest method
case "$DIGEST_METHOD" in
  SHA224)
    DIGEST_ALGO='http://www.w3.org/2001/04/xmldsig-more#sha224' ;;
  SHA256)
    DIGEST_ALGO='http://www.w3.org/2001/04/xmlenc#sha256' ;;
  SHA384)
    DIGEST_ALGO='http://www.w3.org/2001/04/xmldsig-more#sha384' ;;
  SHA512)
    DIGEST_ALGO='http://www.w3.org/2001/04/xmlenc#sha512' ;;
  *)
    error "Unsupported digest method $DIGEST_METHOD, check with $0" ;;
esac

# Target file
PKCS7_RESULT=$3
[ -f "$PKCS7_RESULT" ] && error "Target file $PKCS7_RESULT already exists"

case "$MSGTYPE" in
  # MessageType is SOAP. Define the Request
  SOAP)
    REQ_SOAP='<?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                   xmlns="urn:oasis:names:tc:dss:1.0:core:schema"
                   xmlns:ais="http://service.ais.swisscom.com/"
                   xmlns:dsig="http://www.w3.org/2000/09/xmldsig#">
      <soap:Body>
        <ais:sign>
          <SignRequest RequestID="'$REQUESTID'" Profile="urn:com:swisscom:dss:v1.0">
            <OptionalInputs>
              <ClaimedIdentity Format="urn:com:swisscom:dss:v1.0:entity">
                <Name>'$AP_ID'</Name>
              </ClaimedIdentity>
              <SignatureType>urn:ietf:rfc:3161</SignatureType>
              <AdditionalProfile>urn:oasis:names:tc:dss:1.0:profiles:timestamping</AdditionalProfile>
            </OptionalInputs>
            <InputDocuments>
              <DocumentHash>
                <dsig:DigestMethod Algorithm="'$DIGEST_ALGO'"/>
                <dsig:DigestValue>'$DIGEST_VALUE'</dsig:DigestValue>
              </DocumentHash>
            </InputDocuments>
          </SignRequest>
        </ais:sign>
      </soap:Body>
    </soap:Envelope>'
    # store into file
    echo "$REQ_SOAP" > $REQ ;;

  # MessageType is XML. Define the Request
  XML)
    REQ_XML='<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <SignRequest RequestID="'$REQUESTID'" Profile="urn:com:swisscom:dss:v1.0"
                 xmlns="urn:oasis:names:tc:dss:1.0:core:schema"
                 xmlns:dsig="http://www.w3.org/2000/09/xmldsig#">
        <OptionalInputs>
            <ClaimedIdentity>
                <Name>'$AP_ID'</Name>
            </ClaimedIdentity>
            <SignatureType>urn:ietf:rfc:3161</SignatureType>
            <AdditionalProfile>urn:oasis:names:tc:dss:1.0:profiles:timestamping</AdditionalProfile>
        </OptionalInputs>
        <InputDocuments>
            <DocumentHash>
                <dsig:DigestMethod Algorithm="'$DIGEST_ALGO'"/>
                <dsig:DigestValue>'$DIGEST_VALUE'</dsig:DigestValue>
            </DocumentHash>
        </InputDocuments>
    </SignRequest>'
    # store into file
    echo "$REQ_XML" > $REQ ;;
    
  # MessageType is JSON. Define the Request
  JSON)
    REQ_JSON='{
    "dss.SignRequest": {
        "@RequestID": "'$REQUESTID'",
        "@Profile": "urn:com:swisscom:dss:v1.0",
        "dss.OptionalInputs": {
            "dss.ClaimedIdentity": {"dss.Name": "'$AP_ID'"},
            "dss.SignatureType": "urn:ietf:rfc:3161",
            "dss.AdditionalProfile": "urn:oasis:names:tc:dss:1.0:profiles:timestamping"
        },
        "dss.InputDocuments": {"dss.DocumentHash": {
            "xmldsig.DigestMethod": {"@Algorithm": "'$DIGEST_ALGO'"},
            "xmldsig.DigestValue": "'$DIGEST_VALUE'"
          }
        }
      }
    }'
    # store into file
    echo "$REQ_JSON" > $REQ ;;
    
  # Unknown message type
  *)
    error "Unsupported message type $MSGTYPE, check with $0" ;;
    
esac

# Check existence of needed files
[ -r "${SSL_CA}" ]    || error "CA certificate/chain file ($CERT_CA) missing or not readable"
[ -r "${CERT_KEY}" ]  || error "SSL key file ($CERT_KEY) missing or not readable"
[ -r "${CERT_FILE}" ] || error "SSL certificate file ($CERT_FILE) missing or not readable"

# Define cURL Options according to Message Type
case "$MSGTYPE" in
  SOAP)
    URL=https://ais.pre.swissdigicert.ch/DSS-Server/ws
    HEADER_ACCEPT="Accept: application/xml"
    HEADER_CONTENT_TYPE="Content-Type: text/xml; charset=utf-8"
    CURL_OPTIONS="--data" ;;
  XML)
    URL=https://ais.pre.swissdigicert.ch/DSS-Server/rs/v1.0/sign
    HEADER_ACCEPT="Accept: application/xml"
    HEADER_CONTENT_TYPE="Content-Type: application/xml"
    CURL_OPTIONS="--request POST --data" ;;
  JSON)
    URL=https://ais.pre.swissdigicert.ch/DSS-Server/rs/v1.0/sign
    HEADER_ACCEPT="Accept: application/json"
    HEADER_CONTENT_TYPE="Content-Type: application/json"
    CURL_OPTIONS="--request POST --data-binary" ;;
esac

# Call the service
http_code=$(curl --write-out '%{http_code}\n' --sslv3 --silent \
  $CURL_OPTIONS @$REQ \
  --header "${HEADER_ACCEPT}" --header "${HEADER_CONTENT_TYPE}" \
  --cert $CERT_FILE --cacert $SSL_CA --key $CERT_KEY \
  --output $REQ.res --trace-ascii $REQ.log \
  --connect-timeout $TIMEOUT_CON \
  $URL)

# Results
export RC=$?

if [ "$RC" = "0" -a "$http_code" = "200" ]; then
  case "$MSGTYPE" in
    SOAP|XML)
      # SOAP/XML Parse Result
      RES_MAJ=$(sed -n -e 's/.*<ResultMajor>\(.*\)<\/ResultMajor>.*/\1/p' $REQ.res)
      RES_MIN=$(sed -n -e 's/.*<ResultMinor>\(.*\)<\/ResultMinor>.*/\1/p' $REQ.res)
      RES_MSG=$(cat $REQ.res | tr '\n' ' ' | sed -n -e 's/.*<ResultMessage.*>\(.*\)<\/ResultMessage>.*/\1/p')
      sed -n -e 's/.*<RFC3161TimeStampToken>\(.*\)<\/RFC3161TimeStampToken>.*/\1/p' $REQ.res > $REQ.sig ;;
    JSON)
      # JSON Parse Result
      RES_MAJ=$(sed -n -e 's/^.*"dss.ResultMajor":"\([^"]*\)".*$/\1/p' $REQ.res)
      RES_MIN=$(sed -n -e 's/^.*"dss.ResultMinor":"\([^"]*\)".*$/\1/p' $REQ.res)
      RES_MSG=$(cat $REQ.res | sed 's/\\\//\//g' | sed 's/\\n/ /g' | sed -n -e 's/^.*"dss.ResultMessage":{\([^}]*\)}.*$/\1/p')
      sed -n -e 's/^.*"dss.RFC3161TimeStampToken":"\([^"]*\)".*$/\1/p' $REQ.res | sed 's/\\//g' > $REQ.sig ;;
  esac

  if [ -s "${REQ}.sig" ]; then
    # Decode signature if present
    base64 --decode  $REQ.sig > $REQ.sig.decoded
    [ -s "${REQ}.sig.decoded" ] || error "Unable to decode Base64Signature"
    # Save PKCS7 content to target
    openssl pkcs7 -inform der -in $REQ.sig.decoded -out $PKCS7_RESULT
    # Extract the signers certificate
    openssl pkcs7 -inform der -in $REQ.sig.decoded -out $REQ.sig.cert -print_certs
    [ -s "${REQ}.sig.cert" ] || error "Unable to extract signers certificate from signature"
    RES_ID_CERT=$(openssl x509 -subject -noout -in $REQ.sig.cert)
  fi

  # Status and results
  if [ "$RES_MAJ" = "urn:oasis:names:tc:dss:1.0:resultmajor:Success" ]; then
    RC=0                                                # Ok
    if [ "$VERBOSE" = "1" ]; then                       # Verbose details
      echo "OK on $DIGEST_VALUE with following details:"
      echo " Signer subject : $RES_ID_CERT"
      echo " Result major   : $RES_MAJ with exit $RC"
    fi
   else
    RC=1                                                # Failure
    if [ "$VERBOSE" = "1" ]; then                       # Verbose details
      echo "FAILED on $DIGEST_VALUE with following details:"
      echo " Result major   : $RES_MAJ with exit $RC"
      echo " Result minor   : $RES_MIN"
      echo " Result message : $RES_MSG"
    fi
  fi
 else
  CURL_ERR=$RC                                          # Keep related error
  export RC=2                                           # Force returned error code
  if [ "$VERBOSE" = "1" ]; then                         # Verbose details
    echo "FAILED on $DIGEST_VALUE with following details:"
    echo " curl error : $CURL_ERR"
    echo " http error : $http_code"
  fi
fi

# Debug details
if [ "$DEBUG" != "" ]; then
  [ -f "$REQ" ] && echo ">>> $REQ <<<" && cat $REQ | ( [ "$MSGTYPE" != "JSON" ] && xmllint --format - || python -m json.tool )
  [ -f "$REQ.log" ] && echo ">>> $REQ.log <<<" && cat $REQ.log | grep '==\|error'
  [ -f "$REQ.res" ] && echo ">>> $REQ.res <<<" && cat $REQ.res | ( [ "$MSGTYPE" != "JSON" ] && xmllint --format - || python -m json.tool ) 
  echo ""
fi

# Cleanups if not DEBUG mode
if [ "$DEBUG" = "" ]; then
  [ -f "$REQ" ] && rm $REQ
  [ -f "$REQ.log" ] && rm $REQ.log
  [ -f "$REQ.res" ] && rm $REQ.res
  [ -f "$REQ.sig" ] && rm $REQ.sig
  [ -f "$REQ.sig.decoded" ] && rm $REQ.sig.decoded
  [ -f "$REQ.sig.cert" ] && rm $REQ.sig.cert
  [ -f "$REQ.sig.cert.check" ] && rm $REQ.sig.cert.check
  [ -f "$REQ.sig.txt" ] && rm $REQ.sig.txt
fi

exit $RC

#==========================================================
