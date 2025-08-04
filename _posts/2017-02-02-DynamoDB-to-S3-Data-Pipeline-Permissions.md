---
layout: post
title:  "DynamoDB to S3 Data Pipeline Permissions"
image: ''
date: 2017-02-02 13:34:56
tags:
- AWS
- DynamoDB
- DataPipeline
- IAM
description: ''
categories:
- DynamoDB
- Data Pipeline
---
I use a separate, locked-down AWS account for backups. Each production DynamoDB table has its own Data Pipeline for nightly exports to this backup account.

AWS documentation creates IAM roles with full S3 access (s3:*) for Data Pipeline DynamoDB exports. To maintain maximum restrictions on the backup account and bucket, I determined the minimum required permissions.

Through examining EMR logs and S3 access logs, here are the minimum permissions for a DynamoDB Data Pipeline in account 467398596935 to export cross-account.

This policy assumes exports to `arn:aws:s3:::my-backups-oregon/<date folder>` and logs to `arn:aws:s3:::my-backups-oregon/logs`.

Note: The source account's Data Pipeline IAM role also needs backup bucket access.

{% highlight json %}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::467398596935:root"
      },
      "Action": [
        "s3:PutObject*",
        "s3:GetObject*"
      ],
      "Resource": "arn:aws:s3:::my-backups-oregon/467398596935/*"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::467398596935:root"
      },
      "Action": "s3:DeleteObject",
      "Resource": [
        "arn:aws:s3:::my-backups-oregon/467398596935/*/logs/*",
        "arn:aws:s3:::my-backups-oregon/467398596935/*_$folder$",
        "arn:aws:s3:::my-backups-oregon/467398596935/*.instruction"
      ]
    }
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::467398596935:root"
        ]
      },
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::my-backups-oregon"
    }
  ]
}
{% endhighlight %}

Thanks to <a href="http://codevoyagers.com/2016/07/28/backing-up-an-amazon-web-services-dynamodb/">this post</a> for pointing me toward checking S3 access logs.
