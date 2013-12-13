allin-cmd ./soapui
==================

SoapUI WSDL Project

Contains example requests to invoke the:
* TSA Signature Request (Timestamping)
* Organization Signature Request (Static Keys)
* OnDemand Signature Request (OnDemand Keys)

REGRESSION Test Suite Properties
```
${#TestSuite#AP_ID}
${#TestSuite#STATIC_ID}
${#TestSuite#ONDEMAND_QUALIFIED}
${#TestSuite#ONDEMAND_ADVANCED}
${#TestSuite#MSISDN}
${#TestSuite#SHA224}
${#TestSuite#SHA256}
${#TestSuite#SHA384}
${#TestSuite#SHA512}
${#TestSuite#DIGEST_224}
${#TestSuite#DIGEST_256}
${#TestSuite#DIGEST_384}
${#TestSuite#DIGEST_512}
```

## Known issues

Latest SoapUI builds may throw the following SSL Exception:
javax.net.ssl.SSLPeerUnverifiedException: peer not authenticated

Solution: Download and use SoapUI version 4.0.1. This version used a rather early version of Java 1.6. In a late update of the JRE, Sun plugged some security vulnerabilities, which meant that certain SSL interactions began to be seen as invalid.
