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
With the recent general availability of encryption-at-rest for DynamoDB tables, of course I wanted to enable it on our company tables, but there was a catch - you can't simply enable it on existing DynamoDB tables, you can only enable it when provisioning a new table. Such is life on AWS. I needed to figure out a migration plan.

In the end my plan looked something like this:

1. Update our existing DynamoDB template to enable [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)
2. Create a duplicate of our table with encryption enabled
3. Create a Lambda function which the stream will trigger, which will copy items to the new table
4. Seed the new table with data, if required
5. Update any templates to point to the new table instead of the old one.
6. Finally, delete the old table

To re-iterate the above to be more clear: this has to be a four stage process so you don't lose any data.
* Stage one: deploy template with both tables running side by side and replication
* Stage two: [populate encrypted table using something like this](https://github.com/bchew/dynamodump)
* Stage three: Update the template and/or any other services referencing the original table to instead reference the new encrypted table
* Stage four: Finally, delete the old table

For the case of this article, let's assume our original DynamoDB template looks like this:

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

After doing everything mentioned above, it now looks like:

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
