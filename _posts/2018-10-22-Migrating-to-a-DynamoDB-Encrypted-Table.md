---
layout: post
title:  "Migrating to a DynamoDB encrypted table"
image: ''
date: 2018-10-22 01:20:31
tags:
- CloudFormation
- DynamoDB
- Encryption
description: 'Migrating from a non-encrypted DynamoDB table to a new encrypted table'
categories:
- AWS
---
DynamoDB encryption-at-rest is now available, but you can't enable it on existing tables—only new ones. Here's my migration approach:

1. Enable [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html) on existing table
2. Create encrypted duplicate table
3. Lambda function copies stream items to new table
4. Seed new table with existing data
5. Update templates to reference new table
6. Delete old table

Four-stage deployment prevents data loss:
* **Stage 1**: Deploy both tables with replication
* **Stage 2**: [Populate encrypted table with tool](https://github.com/bchew/dynamodump)
* **Stage 3**: Update services to use encrypted table
* **Stage 4**: Remove old table

Original template:

{% highlight yaml %}
DynamoDbUsers:
  Type: AWS::DynamoDB::Table
  Properties:
    AttributeDefinitions:
      - AttributeName: user
        AttributeType: S
    KeySchema:
      - AttributeName: user
        KeyType: HASH
    ProvisionedThroughput:
      ReadCapacityUnits: 1
      WriteCapacityUnits: 1
{% endhighlight %}

Migration template:

{% highlight yaml %}
dynamoDbUsers:
  Type: AWS::DynamoDB::Table
  Properties:
    StreamSpecification:
      StreamViewType: NEW_IMAGE
    AttributeDefinitions:
      - AttributeName: user
        AttributeType: S
    KeySchema:
      - AttributeName: user
        KeyType: HASH
    ProvisionedThroughput:
      ReadCapacityUnits: 1
      WriteCapacityUnits: 1

dynamoDbUsersEncrypted:
  Type: AWS::DynamoDB::Table
  Properties:
    SSESpecification:
      SSEEnabled: true
    AttributeDefinitions:
      - AttributeName: user
        AttributeType: S
    KeySchema:
      - AttributeName: user
        KeyType: HASH
    ProvisionedThroughput:
      ReadCapacityUnits: 1
      WriteCapacityUnits: 1

tableStream:
  Type: AWS::Lambda::EventSourceMapping
  Properties:
    BatchSize: 1
    Enabled: true
    EventSourceArn: !GetAtt dynamoDbUsers.StreamArn
    FunctionName: !GetAtt replicationFunction.Arn
    StartingPosition: LATEST

replicationLambdaRole:
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
      - PolicyName: LambdaRolePolicy
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - logs:CreateLogGroup
                - logs:CreateLogStream
                - logs:PutLogEvents
              Resource: 'arn:aws:logs:*:*:*'
            - Effect: Allow
              Action:
                - dynamodb:UpdateItem
                - dynamodb:DeleteItem
                - dynamodb:PutItem
                - dynamodb:GetRecords
                - dynamodb:GetShardIterator
                - dynamodb:DescribeStream
                - dynamodb:ListStreams
              Resource: "*"

replicationFunction:
  Type: AWS::Lambda::Function
  Properties:
    Code:
      ZipFile: !Sub |
        import boto3
        import copy
        table = "${dynamoDbUsersEncrypted}"
        def handler(event, context):
          ddb = boto3.client('dynamodb')
          for record in event['Records']:
            try:
              data = record['dynamodb']
              newdata = copy.deepcopy(data)
              args = {
                'TableName': table,
                'Key': data['Keys']
              }
              if record['eventName'] in ['INSERT', 'MODIFY']:
                for k, v in data['NewImage'].items():
                  newdata['NewImage'][k] = {}
                  newdata['NewImage'][k]['Action'] = 'PUT'
                  newdata['NewImage'][k]['Value'] = v
                  if k in data['Keys']:
                      del newdata['NewImage'][k]
                args['AttributeUpdates'] = newdata['NewImage']
                ddb.update_item(**args)
              elif record['eventName'] == 'REMOVE':
                ddb.delete_item(**args)
            except Exception as e:
              print(event)
              print(f'Exception: {e}')

    Handler: index.handler
    Role: !GetAtt replicationLambdaRole.Arn
    Runtime: python3.6
    Timeout: 300
{% endhighlight %}
