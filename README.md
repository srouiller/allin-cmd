allin-cmd
============

All-in command line tools

## bash

Contains a script to invoke the:
* TSA Signature Request
* Organization Signature Request
* OnDemand Signature REquest

```
Usage: ./allin-tsa.sh <args> type hash
  -v       - verbose output
  -d       - debug mode
  digest   - digest/hash to be signed
  method   - digest method (SHA224, SHA256, SHA384, SHA512)

  Example ./allin-tsa.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256
```

```
Usage: ./allin-org.sh <args> type hash
  -v       - verbose output
  -d       - debug mode
  digest   - digest/hash to be signed
  method   - digest method (SHA224, SHA256, SHA384, SHA512)

  Example ./allin-org.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256
```

```
Usage: ./allin-ondemand.sh <args> type hash
  -v       - verbose output
  -d       - debug mode
  digest   - digest/hash to be signed
  method   - digest method (SHA224, SHA256, SHA384, SHA512)
  dn       - distinguished name in the ondemand certificate
  <msisdn> - optional Mobile ID step-up
  <msg>    - optional Mobile ID message
  <lang>   - optional Mobile ID language element (EN, DE, FR, IT)

  Example ./allin-ondemand.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 'cn=Hans Muster,o=ACME,c=CH'
          ./allin-ondemand.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 'cn=Hans Muster,o=ACME,c=CH' +41792080350
          ./allin-ondemand.sh -v GcXfOzOP8GsBu7odeT1w3GnMedppEWvngCQ7Ef1IBMA= SHA256 'cn=Hans Mu
```


The files `mycert.crt`and `mycert.key` are placeholders without any valid content. Be sure to adjust them with your client certificate content in order to connect to the Mobile ID service.

Refer to the "All-In - SOAP client reference guide" document from Swisscom for more details.


Example of verbose outputs:
```
<TODO>
```


## iText

<TODO>


## Known issues

**OS X 10.x: Requests always fail with MSS error 104: _Wrong SSL credentials_.**

The `curl` shipped with OS X uses their own Secure Transport engine, which broke the --cert option, see: http://curl.haxx.se/mail/archive-2013-10/0036.html

Install curl from Mac Ports `sudo port install curl` or home-brew: `brew install curl && brew link --force curl`.
