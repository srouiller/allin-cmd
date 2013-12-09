allin-cmd
============

All-in command line tools

## bash

Contains a script to invoke the:
* TSA Signature Request
* Organization Signature Request
* OnDemand Signature Request

```
Usage: ./allin-tsa.sh <args> digest method pkcs7
  -t value  - message type (SOAP, XML, JSON), default SOAP
  -v        - verbose output
  -d        - debug mode
  digest    - digest/hash to be signed
  method    - digest method (SHA224, SHA256, SHA384, SHA512)
  pkcs7     - output file with PKCS#7 (Crytographic Message Syntax)

  Examples ./allin-tsa.sh GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s
           ./allin-tsa.sh -t JSON -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s
```

```
Usage: ./allin-org.sh <args> digest method pkcs7
  -t value  - message type (SOAP, XML, JSON), default SOAP
  -v        - verbose output
  -d        - debug mode
  digest    - digest/hash to be signed
  method    - digest method (SHA224, SHA256, SHA384, SHA512)
  pkcs7     - output file with PKCS#7 (Crytographic Message Syntax)

  Examples ./allin-org.sh GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s
           ./allin-org.sh -t JSON -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s
```

```
Usage: ./allin-ondemand.sh <args> digest method pkcs7 dn <msisdn> <msg> <lang>
  -t value  - message type (SOAP, XML, JSON), default SOAP
  -v        - verbose output
  -d        - debug mode
  digest    - digest/hash to be signed
  method    - digest method (SHA224, SHA256, SHA384, SHA512)
  pkcs7     - output file with PKCS#7 (Crytographic Message Syntax)
  dn        - distinguished name in the ondemand certificate
  <msisdn>  - optional Mobile ID step-up
  <msg>     - optional Mobile ID message
  <lang>    - optional Mobile ID language element (EN, DE, FR, IT)

  Example ./allin-ondemand.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s 'cn=Hans Muster,o=ACME,c=CH'
          ./allin-ondemand.sh -v -t JSON GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s 'cn=Hans Muster,o=ACME,c=CH'
          ./allin-ondemand.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s 'cn=Hans Muster,o=ACME,c=CH' +41792080350
          ./allin-ondemand.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 result.p7s 'cn=Hans Muster,o=ACME,c=CH' +41792080350 'service.com: Sign?' EN
```


The files `mycert.crt`and `mycert.key` are placeholders without any valid content. Be sure to adjust them with your client certificate content in order to connect to the Mobile ID service.

To create the digest/hast to be signed, here some examples with openssl:
```
  openssl dgst -binary -sha256 myfile.txt | base64
  openssl dgst -binary -sha512 myfile.txt | base64
```

Refer to the "All-In - SOAP client reference guide" document from Swisscom for more details.


Example of verbose outputs:
```
OK on GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= with following details:
 Signer subject : subject= /CN=Hans Muster/O=ACME/C=CH
 Result major   : urn:oasis:names:tc:dss:1.0:resultmajor:Success with exit 0
```

```
FAILED on GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= with following details:
 Result major   : urn:oasis:names:tc:dss:1.0:resultmajor:RequesterError with exit 1
 Result minor   : urn:com:swisscom:dss:1.0:resultminor:InsufficientData
 Result message : MSISDN
```


## iText

<TODO>


## Known issues

**OS X 10.x: Requests always fail with MSS error 104: _Wrong SSL credentials_.**

The `curl` shipped with OS X uses their own Secure Transport engine, which broke the --cert option, see: http://curl.haxx.se/mail/archive-2013-10/0036.html

Install curl from Mac Ports `sudo port install curl` or home-brew: `brew install curl && brew link --force curl`.
