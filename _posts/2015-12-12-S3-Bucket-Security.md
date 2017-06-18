---
layout: post
title:  "S3 Bucket Security"
image: ''
date:   2015-12-12 00:06:31
tags:
- AWS
- S3
description: ''
categories:
- S3
---
I’ve had my AWS account for a few years now.  Back when I first made it I wasn’t too concerned with bucket policies, IAM policies and roles and the rest of it. I was just excited to use AWS and get familiar with it and find out what the big deal was.  One of the first things I did was setup backups of my personal computer to S3.

Fast forward two years and I check my S3 bucket to see what I’ve got in there – oh look, there is a document I need.  So I paste the URL of the S3 object into the browser and it loads straight away.  Wait a minute….. I shouldn’t be able to access that!

Enter the face palm.  I had my S3 bucket with all my passport scans, medical information, driver’s license scans and who knows what else open to the public for years!  It was a serious reality check and I locked it down immediately.

After that incident I got curious. I said to myself, “if I did that when I was an AWS noob, I wonder what other people have done?”.  I had the idea to have a peek at what S3 buckets are available without proper permissions on them.  My “friend” decided to create a script that does the following:

Loads a dictionary file with an English wordlist
Loop through each word that is greater than 3 letters (minimum bucket length), check that bucket exists
If bucket exists, attempt to list objects in the bucket.  Continue on exception, attempt to download one file if successful.
There is some error checking involved in this of course, for example: you get a different error if the bucket doesn’t exist, compared to if it is in another region.
It was staggering how many buckets are open to the public – not just static assets, either, but people’s and business’s personal files.  Unfortunately my “friend” doesn’t have the script anymore (damn Slack free version history!), most people will be able to recreate it themselves – it was only about 40 lines.

Anyway, in conclusion, it was a serious wakeup call and I advise you to check your own bucket permissions.
