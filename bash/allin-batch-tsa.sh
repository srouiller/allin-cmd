#!/bin/bash
# allin--batch-tsa.sh - 1.0
#
# Generic script using curl to invoke Swisscom Allin service: TSA
# Dependencies: curl, openssl, base64, sed, date, xmllint
#
# Change Log:
#  1.0 12.12.2013: Initial version

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
  [ "$VERBOSE" = "1" ] && echo "$@" >&2         # Verbose details
  exit 1                                        # Exit
}

# Check command line
DEBUG=
VERBOSE=
ENCRYPT=
while getopts "dv" opt; do                      # Parse the options
  case $opt in
    d) DEBUG=1 ;;                               # Debug
    v) VERBOSE=1 ;;                             # Verbose
  esac
done
shift $((OPTIND-1))                             # Remove the options

if [ $# -lt 2 ]; then                           # Parse the rest of the arguments
  echo "Usage: $0 <args> type hash"
  echo "  -v       - verbose output"
  echo "  -d       - debug mode"
  echo "  method   - digest method (SHA224, SHA256, SHA384, SHA512)"
  echo "  digest   - digest/hash to be signed"
  echo
  echo "  Example $0 -v SHA256 GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA="
  echo "  Example $0 -v SHA256 GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA="
  echo 
  exit 1
fi

PWD=$(dirname $0)                               # Get the Path of the script

# Check the dependencies
for cmd in curl openssl base64 sed date xmllint; do
  hash $cmd &> /dev/null
  if [ $? -eq 1 ]; then error "Dependency error: '$cmd' not found" ; fi
done

# Swisscom Mobile ID credentials
CERT_FILE=$PWD/mycert.crt                       # The certificate that is allowed to access the service
CERT_KEY=$PWD/mycert.key                        # The related key of the certificate

# Swisscom SDCS elements
SSL_CA=$PWD/allin-ssl.crt                       # Bag file for SSL server connection
OCSP_CERT=$PWD/swisscom-ocsp.crt                # OCSP information of the signers certificate
OCSP_URL=http://ocsp.swissdigicert.ch/sdcs-rubin2

# Create temporary SOAP request
RANDOM=$$                                       # Seeds the random number generator from PID of script
INSTANT=$(date +%Y-%m-%dT%H:%M:%S%:z)           # Define instant and request id
REQUESTID=ALLIN.TEST.$((RANDOM%89999+10000)).$((RANDOM%8999+1000))
SOAP_REQ=$(mktemp /tmp/_tmp.XXXXXX)             # SOAP Request goes here
TIMEOUT_CON=90                                  # Timeout of the client connection

# Hash Method
DIGEST_METHOD=$1                                # Digest method

case "$DIGEST_METHOD" in
  "SHA224")
    DIGEST_ALGO='http://www.w3.org/2001/04/xmldsig-more#sha224'
    ;;
  "SHA256")
    DIGEST_ALGO='http://www.w3.org/2001/04/xmlenc#sha256'
    ;;
  "SHA384")
    DIGEST_ALGO='http://www.w3.org/2001/04/xmldsig-more#sha384'
    ;;
  "SHA512")
    DIGEST_ALGO='http://www.w3.org/2001/04/xmlenc#sha512'
    ;;
  *)
    error "Unsupported digest method $DIGEST_METHOD, check with $0"
    ;;
esac

# Define the part of the Batch request
BATCH=""					# clearing the BATCH parameter
count=2					# add a counter for the Document batch ID
shift						# to shift the position of the $# arg to $2
for i in "$@" 			# list the arguments (start at 2 dur to the shift) 
do 
   TMP="<DocumentHash ID=\""$count\""><dsig:DigestMethod Algorithm=\""$DIGEST_ALGO\""/><dsig:DigestValue>\""$i\""</dsig:DigestValue></DocumentHash>"
	count=$((count+1))
	BATCH=$BATCH$TMP	
done
          

# Define the request
cat > $SOAP_REQ <<End
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <ais:sign xmlns="urn:oasis:names:tc:dss:1.0:core:schema"
     xmlns:dsig="http://www.w3.org/2000/09/xmldsig#"
     xmlns:ais="http://service.ais.swisscom.com/">
      <SignRequest Profile="urn:com:swisscom:dss:v1.0" RequestID="$REQUESTID">
        <InputDocuments>
        	$BATCH
        </InputDocuments>
        <OptionalInputs>
          <ClaimedIdentity Format="urn:com:swisscom:dss:v1.0:entity">
            <Name>$AP_ID</Name>
          </ClaimedIdentity>
          <SignatureType>urn:ietf:rfc:3161</SignatureType>
          <AdditionalProfile>urn:oasis:names:tc:dss:1.0:profiles:timestamping</AdditionalProfile>
          <AdditionalProfile>urn:com:swisscom:dss:v1.0:profiles:batchprocessing</AdditionalProfile>
        </OptionalInputs>
      </SignRequest>
    </ais:sign>
  </soap:Body>
</soap:Envelope>
End

# Check existence of needed files
[ -r "${SSL_CA}" ]   || error "CA certificate/chain file ($CERT_CA) missing or not readable"
[ -r "${CERT_KEY}" ]  || error "SSL key file ($CERT_KEY) missing or not readable"
[ -r "${CERT_FILE}" ] || error "SSL certificate file ($CERT_FILE) missing or not readable"
[ -r "${OCSP_CERT}" ] || error "OCSP certificate file ($OCSP_CERT) missing or not readable"

# Call the service
SOAP_URL=https://ais.pre.swissdigicert.ch/DSS-Server/ws
CURL_OPTIONS="--sslv3 --silent"
http_code=$(curl --write-out '%{http_code}\n' $CURL_OPTIONS \
    --data "@${SOAP_REQ}" --header "Content-Type: text/xml; charset=utf-8" \
    --cert $CERT_FILE --cacert $SSL_CA --key $CERT_KEY \
    --output $SOAP_REQ.res --trace-ascii $SOAP_REQ.log \
    --connect-timeout $TIMEOUT_CON \
    $SOAP_URL)

# Results
export RC=$?
if [ "$RC" = "0" -a "$http_code" -eq 200 ]; then
  # Parse the response xml
  RES_MAJ=$(sed -n -e 's/.*<ResultMajor>\(.*\)<\/ResultMajor>.*/\1/p' $SOAP_REQ.res)
  RES_MIN=$(sed -n -e 's/.*<ResultMinor>\(.*\)<\/ResultMinor>.*/\1/p' $SOAP_REQ.res)
  sed -n -e 's/.*<RFC3161TimeStampToken>\(.*\)<\/RFC3161TimeStampToken>.*/\1/p' $SOAP_REQ.res > $SOAP_REQ.sig

  if [ -s "${SOAP_REQ}.sig" ]; then
    # Decode signature if present
    base64 --decode  $SOAP_REQ.sig > $SOAP_REQ.sig.decoded
    [ -s "${SOAP_REQ}.sig.decoded" ] || error "Unable to decode Base64Signature"
    # Extract the signers certificate
    openssl pkcs7 -inform der -in $SOAP_REQ.sig.decoded -out $SOAP_REQ.sig.cert -print_certs
    [ -s "${SOAP_REQ}.sig.cert" ] || error "Unable to extract signers certificate from signature"
    RES_ID_CERT=$(openssl x509 -subject -noout -in $SOAP_REQ.sig.cert)
  fi

  ## TODO
  echo "Signer subject: $RES_ID_CERT"
  echo "Result Major: $RES_MAJ"
  echo "Result Minor: $RES_MIN"

 else
  CURL_ERR=$RC                                          # Keep related error
  export RC=2                                           # Force returned error code
  if [ "$VERBOSE" = "1" ]; then                         # Verbose details
    [ $CURL_ERR != "0" ] && echo "curl failed with $CURL_ERR"   # Curl error
    if [ -s "${SOAP_REQ}.res" ]; then                           # Response from the service
      RES_MAJ=$(sed -n -e 's/.*<ResultMajor>\(.*\)<\/ResultMajor>.*/\1/p' $SOAP_REQ.res)
      RES_MIN=$(sed -n -e 's/.*<ResultMinor>\(.*\)<\/ResultMinor>.*/\1/p' $SOAP_REQ.res)
      echo "FAILED on $DIGEST_VALUE with $RES_MAJ:$RES_MIN and exit $RC"
    fi
  fi
fi

# Debug details
if [ "$DEBUG" != "" ]; then
  [ -f "$SOAP_REQ" ] && echo ">>> $SOAP_REQ <<<" && cat $SOAP_REQ | xmllint --format -
  [ -f "$SOAP_REQ.log" ] && echo ">>> $SOAP_REQ.log <<<" && cat $SOAP_REQ.log | grep '==\|error'
  [ -f "$SOAP_REQ.res" ] && echo ">>> $SOAP_REQ.res <<<" && cat $SOAP_REQ.res | xmllint --format -
fi

# Cleanups if not DEBUG mode
#if [ "$DEBUG" = "" ]; then
  [ -f "$SOAP_REQ" ] && rm $SOAP_REQ
  [ -f "$SOAP_REQ.log" ] && rm $SOAP_REQ.log
  [ -f "$SOAP_REQ.res" ] && rm $SOAP_REQ.res
  [ -f "$SOAP_REQ.sig" ] && rm $SOAP_REQ.sig
  [ -f "$SOAP_REQ.sig.decoded" ] && rm $SOAP_REQ.sig.decoded
  [ -f "$SOAP_REQ.sig.cert" ] && rm $SOAP_REQ.sig.cert
  [ -f "$SOAP_REQ.sig.cert.check" ] && rm $SOAP_REQ.sig.cert.check
  [ -f "$SOAP_REQ.sig.txt" ] && rm $SOAP_REQ.sig.txt
#fi

exit $RC

#==========================================================
