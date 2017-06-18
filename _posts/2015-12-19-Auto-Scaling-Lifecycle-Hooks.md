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
Recently I was at a client and they asked me if it was possible to retrieve the logs from their instances before they terminated.  Having sat the Solutions Architect Professional exam and having answered lot of questions around auto scaling, the answer I gave the client was yes.

I won’t regurgitate the documentation and explain what exactly auto scaling lifecycle hooks are.  If you found this page you probably already know, and if you don’t you can read about them at <a href="http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/introducing-lifecycle-hooks.html">http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/introducing-lifecycle-hooks.html</a>.  What I will go into is the practical use of the lifecycle hooks.

To have successful auto scaling lifecycle hooks three things are required:

IAM roles with policies supporting setting up the lifecycle hooks and processing the hooks.
An SQS (or SNS – in this case SQS, though) queue to receive the lifecycle notifications.
Some sort of daemon running on your instances that polls the SQS queue and looks for termination messages specifically relating to the instance.
Now none of this is particularly hard.   The issue lies in actually putting everything together.  There is little to no existing snippets on the internet regarding this, so I was pretty much on my own when I put it all together.  Oh, I better mention that I’m not a developer by profession so if my code looks bad don’t judge me too much.

The general thought process around how I setup my hooks is as follows:

1. Create a python daemon using boto3 that creates a lifecycle hook.  It doesn’t care if a hook already exists.  Launch the daemon on first boot (using CloudFormation cfn-init) and on reboot (using Cron).
2. Do a continuous loop long-polling SQS for messages.
3. If the message does not match the current instance, change the message visibility timeout to 0 and continue with the loop. Else:
4. Delete the message from SQS.
5. Download a bash script from an S3 bucket and execute it.
6. Notify the ASG that the lifecycle action is completed.

The complete python code can be found <a href="/assets/attachments/as-lifecyclehooks.py.txt">here</a>.  Some static variables in the script need to be changed.  I would normally deploy it via a CloudFormation template as part of whatever stack I am working on and have the template set the variables.  I’ve made my CloudFormation skeleton for auto scaling lifecycle hooks available here.  The only thing manual that needs to be done is placing the OnTermination scripts into the bucket after the template creates it. My OnTermination script looks something like:

{% highlight sh %}
#!/bin/bash
INSTANCE_ID=$(wget -q -O - http://instance-data/latest/meta-data/instance-id)
aws s3 cp /var/log/messages "s3://test2-s3bucket-1asdfg1et/${INSTANCE_ID}-messages.txt"
{% endhighlight %}

While I’m on the subject of CloudFormation templates and executing other scripts, what I usually do and have found to be easier to manage than hard coding a lot of scripts, is to create one single bootstrap script, place that in S3 and use the instance userdata to copy it down and execute it.  In the template I create a script which does a bunch of export statements to set environment variables and the bootstrap script loads that.  Doing this this allows much more flexibility around testing because you can run the script on an existing instance, make sure it works ok, then copy it up to S3 without having to adjust the CloudFormation template and cause a scaling event to get an instance with the new version.
