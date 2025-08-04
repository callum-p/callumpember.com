---
layout: post
title:  "CloudFormation Custom Resources"
image: ''
date: 2016-01-18 19:58:03
tags:
- AWS
- CloudFormation
- Custom Resources
description: ''
categories:
- CloudFormation
---
CloudFormation limitations include:
- Resources can only be created in the deployment region
- No programmatic data lookup (e.g., regional AMIs)
- Can't retrieve database data needed for templates (subnet CIDR, SQL passwords)
- Limited stack creation/deletion actions beyond notifications

CloudFormation custom resources solve these problems. They're Lambda or SNS-backed functions that your template calls with specified parameters. The function executes any logic and returns data to the stack with a SUCCESS or FAILURE status.

While NodeJS examples are common, Python examples are scarce. I've created <a href="/assets/attachments/cfncustomresource.py_.txt">this helper class</a> that simplifies the process, allowing you to create custom resources in about 15 lines of code.

Basic skeleton using the helper:

{% highlight python %}
from cfncustomresource import CustomResource
cr = None

def oncreate():
  cr.success(response={'SampleOutput': 'SampleValue'})

def ondelete():
  cr.success(response={})

def onupdate():
  cr.success(response={})

def handler(event, context):
  global cr
  cr = CustomResource()
  cr.add_hook('create', oncreate)
  cr.add_hook('delete', ondelete)
  cr.add_hook('update', onupdate)
  cr.load_event(event)
{% endhighlight %}

The custom resource JSON template:

{% highlight python %}
"CustomLambdaResource" : {
  "Type"             : "Custom::LambdaSubnetLookup",
  "Properties" : {
    "ServiceToken"    : { "Fn::Join": [ "", [ "arn:aws:lambda:", { "Ref" : "LambdaSubnetLookupRegion" }, ":", { "Ref": "AWS::AccountId" }, ":function:", {"Ref" : "LambdaSubnetLookup"} ] ] },
    "Cidr"           : { "Ref" : "VpcCidr" },
    "SubnetMask"      : { "Ref" : "SubnetMask" },
    "DynamoDbRegion"  : { "Ref" : "DynamoDbRegion" },
    "DynamoDbTable"   : { "Ref" : "DynamoDbTable" }
  }
}
{% endhighlight %}

Documentation: <a href="http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html">http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html</a>
