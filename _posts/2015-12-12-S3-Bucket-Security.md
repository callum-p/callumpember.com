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
When I first started with AWS, I wasn't concerned with bucket policies, IAM policies and roles. I was just excited to explore AWS and immediately set up backups of my personal computer to S3.

Two years later, I needed a document from my S3 bucket. I pasted the URL into the browser and it loaded straight away. Wait – I shouldn't be able to access that!

My S3 bucket with passport scans, medical information, driver's license scans and more had been publicly accessible for years. I locked it down immediately.

This incident made me curious about how many other S3 buckets might have improper permissions. A script was created that:

1. Loads a dictionary file with an English wordlist
2. Loops through each word greater than 3 letters (minimum bucket length)
3. Checks if that bucket name exists
4. If it exists, attempts to list objects and download a file

The error checking distinguishes between non-existent buckets and buckets in different regions.

The results were staggering – many buckets are publicly accessible, containing not just static assets but personal and business files. The script was about 40 lines of code.

This was a serious wake-up call. Check your bucket permissions.
