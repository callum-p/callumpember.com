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
Sometimes when you’re using CloudFormation you encounter limitations like:
– Can only create resources in the same region you deploy the template to
– Can’t programmatically look up data, e.g. the AMIs in the region
– Can’t retrieve some data from a DB that you need to create the template, e.g. subnet CIDR or SQL password.
– No built in function for actions to perform on stack creation / deletion, besides regular notifications

The answer to all these problems and more is CloudFormation custom resources. Custom resources are essentially Lambda or SNS backed (with SNS you can easily use an external resource) functions that the CF template calls, using whatever parameters are specified. The function can then go and do whatever it wants and return data back to the stack, along with a SUCCESS or FAILURE message.

There are plenty of examples out there for NodeJS custom resources, but the Python examples are quite lacking. I’ve created <a href="/assets/attachments/cfncustomresource.py_.txt">this helper class</a> to make the entire process a lot easier and a lot cleaner. Instead of building the response and parsing functions manually and repeatedly, the class makes you be able to create a custom resource in about 15 lines of code.

Using the helper, a basic skeleton custom resource would look like:

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

The custom resource json would look something along the lines of:

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

For more information and the actual custom resource specification, you can have a look at the documentation at <a href="http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html">http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html</a>.
