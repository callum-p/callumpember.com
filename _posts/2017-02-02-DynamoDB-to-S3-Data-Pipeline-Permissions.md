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
As per best practice, I have a seperate AWS account that is strictly locked down to store all my backups. In my production account, every DynamoDB table deployed gets it’s own Data Pipeline also, to export it nightly to a bucket in the backup account.

One of my pet peeves with the AWS documentation for Data Pipeline DynamoDB exports is that the IAM role they create (and the example role) has full IAM S3 access, aka s3:\*. This wasn’t acceptable to me, as I wanted the backup account & bucket as locked down as possible.

After a VERY tedious process of figuring out what privileges EMR needed to backup – mostly through trial and error of looking at the EMR logs, and when that didn’t provide enough information, enabling S3 access logs on the bucket, the below policy is the minimum required to allow a DynamoDB Data Pipeline in account 467398596935, to export to a bucket in another arbitrary account.

The bucket policy below assumes the export will be exporting data to arn:aws:s3:::my-backups-oregon/<date folder> and EMR/Data Pipeline logs going to arn:aws:s3:::my-backups-oregon/logs

Remember, in the account actually doing the backups, the IAM role for the Data Pipeline resources will need access to the backup bucket too.

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

A massive thanks to <a href="http://codevoyagers.com/2016/07/28/backing-up-an-amazon-web-services-dynamodb/">http://codevoyagers.com/2016/07/28/backing-up-an-amazon-web-services-dynamodb/</a>" for pointing me in the right direction of checking the S3 access logs.
