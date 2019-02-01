---
layout: post
title:  "Validating an ACM cert with CloudFormation"
image: ''
date: 2019-02-01 00:10:09
tags:
- CloudFormation
- Lambda
- Python
- ACM
description: 'Using a CloudFormation Custom Resource to validate an ACM cert also created by CloudFormation'
categories:
- AWS
---
Creating ACM certificates via CloudFormation is cool, but validation isn't.

The below template will create the ACM certificate and a Lambda custom resource.

The custom resource will poll the CloudFormation stack waiting for the ACM certificate resource to output an event with the DNS validation record details.

Once the event has been emitted, the custom resource will go on to create the required DNS records for validation.  Once ACM has performed it's validation, the stack will finish creating successfully.

{% highlight yaml %}
Description: Deploys an ACM certificate and DNS validation records

Parameters:
  zoneName:
    Type: String
  domainName:
    Type: String

Resources:
  certificate:
    Type: AWS::CertificateManager::Certificate
    Properties:
      DomainName: !Ref domainName
      SubjectAlternativeNames:
        - !Sub "*.${domainName}"
      ValidationMethod: DNS

  certValidationResource:
    Type: Custom::CertValidation
    Properties:
      ServiceToken: !GetAtt lambdaFunction.Arn
      HostedZoneName: !Ref zoneName
      StackName: !Ref 'AWS::StackName'

  lambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
        - Effect: Allow
          Principal:
            Service:
              - lambda.amazonaws.com
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
            Resource: '*'
          - Effect: Allow
            Action:
              - route53:ChangeResourceRecordSets
              - route53:ListHostedZonesByName
              - cloudformation:DescribeStackEvents
            Resource: '*'

  lambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      Runtime: python3.6
      Timeout: '300'
      Handler: index.handler
      Role: !GetAtt lambdaRole.Arn
      Code:
        ZipFile: |
          #!/usr/bin/env python3

          import cfnresponse
          import boto3
          import re
          import time


          def get_zone_id_from_name(zone_name):
              r53 = boto3.client('route53')
              r = r53.list_hosted_zones_by_name(DNSName=zone_name)
              for hz in r['HostedZones']:
                  return hz['Id']


          def get_stack_cert_event(stack_name):
              cfn = boto3.client('cloudformation')
              params = {'StackName': stack_name}
              event = None
              while True:
                  r = cfn.describe_stack_events(**params)
                  for e in r['StackEvents']:
                      if (
                          e['ResourceType'] == 'AWS::CertificateManager::Certificate' and
                          e['ResourceStatus'] == 'CREATE_IN_PROGRESS' and
                          'ResourceStatusReason' in e and
                          'Content of DNS Record' in e['ResourceStatusReason']
                      ):
                          event = e
                  if 'NextToken' in r:
                      params['NextToken'] = r['NextToken']
                  else:
                      break
              return event


          def parse_event(event):
              reason = event['ResourceStatusReason']
              m = re.search(r'\{Name\: (.+),\s?Type\: (.+),\s?Value\: (.+)\}', reason)
              if m:
                  dns = {
                      'Name': m.group(1),
                      'Type': m.group(2),
                      'Value': m.group(3)
                  }
                  return dns
              return None


          def upsert(hosted_zone_id, dns_record):
              r53 = boto3.client('route53')
              r53.change_resource_record_sets(
                  HostedZoneId=hosted_zone_id,
                  ChangeBatch={
                      'Changes': [{
                          'Action': 'UPSERT',
                          'ResourceRecordSet': {
                              'Name': dns_record['Name'],
                              'Type': dns_record['Type'],
                              'TTL': 60,
                              'ResourceRecords': [{
                                  'Value': dns_record['Value']
                              }]
                          }
                      }]
                  }
              )


          def handler(event, context):
              try:
                  if event['RequestType'] == 'Create':
                      cert_event = None
                      while cert_event is None:
                          cert_event = get_stack_cert_event(
                            event['ResourceProperties']['StackName'])
                          time.sleep(5)
                      dns_record = parse_event(cert_event)
                      if dns_record:
                          hosted_zone_id = get_zone_id_from_name(
                              event['ResourceProperties']['HostedZoneName'])
                          upsert(hosted_zone_id, dns_record)
              except Exception as e:
                  print(e)
              finally:
                  if 'Offline' not in event['ResourceProperties']:
                      cfnresponse.send(event, context, cfnresponse.SUCCESS, {})


          if __name__ == '__main__':
              event = {
                  'ResourceProperties': {
                      'HostedZoneName': 'x.x.x',
                      'Offline': True
                  }
              }
              handler(event, None)


Outputs:
  certificateArn:
    Value: !Ref certificate

{% endhighlight %}
