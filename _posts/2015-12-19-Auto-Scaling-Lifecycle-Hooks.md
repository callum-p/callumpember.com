---
layout: post
title:  "Autoscaling Lifecycle Hooks"
image: ''
date: 2015-12-19 00:19:22
tags:
- AWS
- EC2
- Autoscaling
- Lifecycle hooks
description: ''
categories:
- Autoscaling
---
A client needed to retrieve logs from instances before termination. Auto scaling lifecycle hooks make this possible.

For documentation on lifecycle hooks, see <a href="http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/introducing-lifecycle-hooks.html">http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/introducing-lifecycle-hooks.html</a>. This post focuses on practical implementation.

Three requirements for successful auto scaling lifecycle hooks:

1. IAM roles with policies for setting up and processing hooks
2. An SQS queue (or SNS) to receive lifecycle notifications
3. A daemon on instances that polls SQS for termination messages

The challenge is putting everything together, as there are few existing code examples online.

My implementation process:

1. Create a Python daemon using boto3 that creates a lifecycle hook. Launch via CloudFormation cfn-init on first boot and Cron on reboot
2. Long-poll SQS for messages continuously
3. For non-matching instances, reset message visibility timeout to 0 and continue
4. For matching instances, delete the message from SQS
5. Download and execute bash script from S3 bucket
6. Notify ASG that lifecycle action is completed

The complete Python code is available <a href="/assets/attachments/as-lifecyclehooks.py.txt">here</a>. Deploy it via CloudFormation template to set the required variables. The OnTermination scripts must be manually placed in the bucket after template creation.

Example OnTermination script:

{% highlight sh %}
#!/bin/bash
INSTANCE_ID=$(wget -q -O - http://instance-data/latest/meta-data/instance-id)
aws s3 cp /var/log/messages "s3://test2-s3bucket-1asdfg1et/${INSTANCE_ID}-messages.txt"
{% endhighlight %}

Tip for CloudFormation templates: Instead of hard-coding scripts, create a single bootstrap script in S3 and use userdata to download and execute it. The template can generate environment variables via export statements that the bootstrap script loads. This enables testing on existing instances without modifying the CloudFormation template or triggering scaling events.
