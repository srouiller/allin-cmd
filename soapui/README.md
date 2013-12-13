allin-cmd: SoapUI Project
======

### Introduction

SoapUI is an open source web service testing application for service-oriented architectures (SOA). Its functionality covers web service inspection, invoking, development, simulation and mocking, functional testing, load and compliance testing. SoapUI has been given a number of awards.
You can get SoapUI at http://sourceforge.net/projects/soapui/

A SoapUI Project has been created that contains example requests to invoke:
* TSA Signature Request
* Organization Signature Request
* OnDemand Signature Request

### Automatic Regression Test

This SoapUI Project contains a Test Suite for Automatic Regression Test against the AIS Service.
It supports SOAP as well as RESTful (XML/JSON) interface.

##### Custom Properties:

| Property Variable | Default Value |
| :------------- | :------------- |
${#TestSuite#AP_ID}|cartel.ch
${#TestSuite#STATIC_ID}|:kp2-cartel.ch
${#TestSuite#ONDEMAND_QUALIFIED}|:OnDemand-Qualified
${#TestSuite#ONDEMAND_ADVANCED}|:OnDemand-Advanced
${#TestSuite#MSISDN}|41793083455
${#TestSuite#SHA224}|http://www.w3.org/2001/04/xmldsig-more#sha224
${#TestSuite#SHA256}|http://www.w3.org/2001/04/xmlenc#sha256
${#TestSuite#SHA384}|http://www.w3.org/2001/04/xmldsig-more#sha384
${#TestSuite#SHA512}|http://www.w3.org/2001/04/xmlenc#sha512
${#TestSuite#DIGEST_224}|YyNmU8FIXM0wNgdcmZyJIW1S3f8KbOcN8Ulgzw==
${#TestSuite#DIGEST_256}|1WON4H3Hrinf7LYRNmhV6Uf7apdUvuYEsmhxAklxumA=
${#TestSuite#DIGEST_384}|be5JJtVMoZqkJ3isZaBBpwXXQtV4Opqf3KtYcHacCh7fVZ1bS8VSnMnK3z9mIy1R
${#TestSuite#DIGEST_512}|FsntfB/ATHb1O7HlxpB4l9L+1vkgCOki3omkM6jJVnxXDRRgd1uZ7S/GkLPkFEUJ+SDllcWWjDNJHJcnkritGg==
${#TestSuite#tmp_ResponseID}|c086e98c-5951-46ad-ac2a-7f21b8d7be88


### Known issues

n/a
