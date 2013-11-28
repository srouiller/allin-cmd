#!/bin/sh
# allin-ondemand.sh - 1.0
#
# Generic script using curl to invoke Swisscom Allin service: OnDemand
# Dependencies: curl, openssl, base64, sed, date, xmllint
#
# Change Log:
#  1.0 26.11.2013: Initial version

######################################################################
# User configurable options
######################################################################

# AP_ID used to identify to Allin (provided by Swisscom)
AP_ID=cartel.ch:OnDemand-Qualified

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

if [ $# -lt 3 ]; then                           # Parse the rest of the arguments
  echo "Usage: $0 <args> type hash"
  echo "  -v       - verbose output"
  echo "  -d       - debug mode"
  echo "  digest   - digest/hash to be signed"
  echo "  method   - digest method (SHA224, SHA256, SHA384, SHA512)"
  echo "  dn       - distinguished name in the ondemand certificate"
  echo "  <msisdn> - optional Mobile ID step-up"
  echo "  <msg>    - optional Mobile ID message"
  echo "  <lang>   - optional Mobile ID language element (EN, DE, FR, IT)"
  echo
  echo "  Example $0 -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 'cn=Hans Muster,o=ACME,c=CH'"
  echo "          $0 -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 'cn=Hans Muster,o=ACME,c=CH' +41792080350"
  echo "          $0 -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 'cn=Hans Muster,o=ACME,c=CH' +41792080350 'service.com: Sign?' EN"
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

# Hash and digests
DIGEST_VALUE=$1                                 # Hash to be signed
DIGEST_METHOD=$2                                # Digest method
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

# OnDemand distinguished name
ONDEMAND_DN=$3

# Optional step up with Mobile ID
MID=""                                          # MobileID step up by default off
MID_MSISDN=$4                                   # MSISDN
MID_MSG=$5                                      # Optional DTBS
[ "$MID_MSG" = "" ] && MID_MSG="Sign it?"
MID_LANG=$6                                     # Optional Language
[ "$MID_LANG" = "" ] && MID_LANG="EN"
if [ "$MID_MSISDN" != "" ]; then                # MobileID step up?
  MID="<ns5:StepUpAuthorisation><ns5:MobileID><ns5:MSISDN>$MID_MSISDN</ns5:MSISDN><ns5:Message>$MID_MSG</ns5:Message><ns5:Language>$MID_LANG</ns5:Language></ns5:MobileID></ns5:StepUpAuthorisation>"
fi

# Define the request
cat > $SOAP_REQ <<End
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <ns4:sign xmlns="urn:oasis:names:tc:dss:1.0:core:schema"
     xmlns:ns2="http://www.w3.org/2000/09/xmldsig#"
     xmlns:ns3="urn:oasis:names:tc:dss:1.0:profiles:asynchronousprocessing:1.0"
     xmlns:ns4="http://service.ais.swisscom.com/"
     xmlns:ns5="urn:com:swisscom:dss:1.0:schema">
      <SignRequest Profile="urn:com:swisscom:dss:v1.0" RequestID="$REQUESTID">
        <InputDocuments>
          <DocumentHash>
            <ns2:DigestMethod Algorithm="$DIGEST_ALGO"/>
            <ns2:DigestValue>$DIGEST_VALUE</ns2:DigestValue>
          </DocumentHash>
        </InputDocuments>
        <OptionalInputs>
          <SignatureType>urn:ietf:rfc:3369</SignatureType>
          <ClaimedIdentity>
            <Name>$AP_ID</Name>
          </ClaimedIdentity>
          <AdditionalProfile>urn:com:swisscom:dss:v1.0:profiles:ondemandcertificate</AdditionalProfile>
          <ns5:CertificateRequest>
            <ns5:DistinguishedName>$ONDEMAND_DN</ns5:DistinguishedName>
            $MID
          </ns5:CertificateRequest>
          <AddOCSPResponse Type="urn:ietf:rfc:2560"/>
          <AddTimestamp Type="urn:ietf:rfc:3161"/>
        </OptionalInputs>
      </SignRequest>
    </ns4:sign>
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
  openssl x509 -in $SOAP_REQ.sig.cert -noout -text
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
