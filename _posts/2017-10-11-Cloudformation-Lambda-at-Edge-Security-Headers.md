---
layout: post
title:  "Lambda@Edge for custom HTTP headers"
image: ''
date:   2017-10-11 12:55:31
tags:
- CloudFormation
- Lambda
- Lambda@Edge
description: 'How to use Lambda@Edge for custom HTTP headers'
categories:
- AWS
---
Adding security headers to our CloudFront distribution required Lambda@Edge. The documentation examples broke after the service moved from beta to GA.

Working Lambda function for CloudFront distributions:

{% highlight yaml %}
---
Parameters:
  lambdaVersion:
    Type: Number
    Default: 1

Resources:
  lambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Effect: Allow
          Principal:
            Service:
              - lambda.amazonaws.com
              - edgelambda.amazonaws.com
          Action:
            - sts:AssumeRole
      Path: "/"
      Policies:
      - PolicyName: root
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
          - Effect: Allow
            Action:
              - logs:CreateLogGroup
              - logs:CreateLogStream
              - logs:PutLogEvents
            Resource: arn:aws:logs:*:*:*

  lambdaEdgeResponseFunction:
    Type: AWS::Lambda::Function
    Properties:
      Runtime: nodejs6.10
      Timeout: '1'
      Handler: index.handler
      Role: !GetAtt lambdaExecutionRole.Arn
      Code:
        ZipFile: !Sub |
          'use strict';
           var version = ${lambdaVersion};
           exports.handler = (event, context, callback) => {
             const response = event.Records[0].cf.response;

             response.headers['X-Frame-Options']            = [ { key: 'X-Frame-Options', value: "DENY" } ];
             response.headers['Strict-Transport-Security']  = [ { key: 'Strict-Transport-Security', value: "max-age=31536000; preload" } ];
             response.headers['X-Content-Type-Options']     = [ { key: 'X-Content-Type-Options', value: "nosniff" } ];
             response.headers['X-XSS-Protection']           = [ { key: 'X-XSS-Protection', value: "1; mode=block" } ];
             response.headers['Referrer-Policy']            = [ { key: 'Referrer-Policy', value: "same-origin" } ];

             callback(null, response);
           };

Outputs:
  functionName:
    Value: !Ref lambdaEdgeResponseFunction
  functionArn:
    Value: !GetAtt lambdaEdgeResponseFunction.Arn
{% endhighlight %}
