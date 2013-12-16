#!/bin/sh
# allin-async-poll-org.sh - 1.0
#
# Generic script using curl to invoke Swisscom Allin service: Organization
# Dependencies: curl, openssl, base64, sed, date, xmllint
#
# Change Log:
#  1.0 12.12.2013: Initial version

######################################################################
# User configurable options
######################################################################

# AP_ID used to identify to Allin (provided by Swisscom)
AP_ID=cartel.ch:kp2-cartel.ch

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

if [ $# -lt 1 ]; then                           # Parse the rest of the arguments
  echo "Usage: $0 <args> type hash"
  echo "  -v            - verbose output"
  echo "  -d            - debug mode"
  echo "  response id   - The response id of the initial response"
  echo "  <request id>  - The request id to compare with"
  echo
  echo "  Example $0 -v aeff8212-8875-4b6a-8502-91afe6e0dc28"
  echo "          $0 -v aeff8212-8875-4b6a-8502-91afe6e0dc28 aeff8212-8875-4b6a-8502-91afe6e0dc28"
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
SOAP_REQ=$(mktemp /tmp/_tmp.XXXXXX)             # SOAP Request goes here
TIMEOUT_CON=90                                  # Timeout of the client connection

# get Response ID 
RESPONSEID=$1					# Response ID of the initial response
# if request ID exist, get it
if test $# -eq 2 				# test the number of arguments
  then
    REQUESTID_orig=$2				# Request ID of the initial request
fi

# Define the request
cat > $SOAP_REQ <<End
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <ais:pending xmlns="urn:oasis:names:tc:dss:1.0:core:schema"
     xmlns:dsig="http://www.w3.org/2000/09/xmldsig#"
     xmlns:ais3="urn:oasis:names:tc:dss:1.0:profiles:asynchronousprocessing:1.0" 
     xmlns:ais="http://service.ais.swisscom.com/"
     xmlns:ais5="urn:com:swisscom:dss:1.0:schema">
      <ais3:PendingRequest Profile="urn:com:swisscom:dss:v1.0">
        <OptionalInputs>
	  		 <ClaimedIdentity>
            <Name>$AP_ID</Name>
          </ClaimedIdentity>
	  		 <ais3:ResponseID>$RESPONSEID</ais3:ResponseID>
        </OptionalInputs>
      </ais3:PendingRequest>
    </ais:pending>
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
  REQUESTID_return=$(sed -n -e 's/.*RequestID=\"\(.*\)\" Profile.*/\1/p' $SOAP_REQ.res)
  RES_MAJ=$(sed -n -e 's/.*<ResultMajor>\(.*\)<\/ResultMajor>.*/\1/p' $SOAP_REQ.res)
  RES_MIN=$(sed -n -e 's/.*<ResultMinor>\(.*\)<\/ResultMinor>.*/\1/p' $SOAP_REQ.res)
  sed -n -e 's/.*<Base64Signature Type="urn:ietf:rfc:3369">\(.*\)<\/Base64Signature>.*/\1/p' $SOAP_REQ.res > $SOAP_REQ.sig

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
  if test -n  "$REQUESTID_orig"; then
    if [ "$REQUESTID_orig" = "$REQUESTID_return" ]; then 
      openssl x509 -in $SOAP_REQ.sig.cert -noout -text
      echo "Request ID of the request and of the reponse MATCH"
      echo "Request ID : $REQUESTID_return"
      echo "Response ID polled: $RESPONSEID"
      echo "Signer subject: $RES_ID_CERT"
      echo "Result Major: $RES_MAJ"
      echo "Result Minor: $RES_MIN"
    else
      echo "The Request ID of the request and of the response DON'T MATCH"
    fi 
  else
    openssl x509 -in $SOAP_REQ.sig.cert -noout -text
    echo "Response ID polled: $RESPONSEID"
    echo "Signer subject: $RES_ID_CERT"
    echo "Result Major: $RES_MAJ"
    echo "Result Minor: $RES_MIN"
  fi 

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
