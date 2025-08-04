---
layout: post
title:  "A short post on RDS SQL Server S3"
image: ''
date: 2016-08-11 15:12:42
tags:
- AWS
- RDS
- S3
description: ''
categories:
- RDS
---
AWS released RDS SQL Server S3 Import/Export just in time for our SQL Server migration. <a href="http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/SQLServer.Procedural.Importing.html">Documentation here</a>.

While excellent for migrations, the feature has limitations:

1. SQL agent jobs can't schedule S3 backups/restores due to credential passing issues (confirmed by AWS support)
2. Backups are several times larger than standard SQL backups—likely copying entire backup sets rather than individual backups, slowing staging/pre-production restores
3. Only one restored database version can exist per server, regardless of naming

Despite these issues, the feature simplifies staging/pre-production deployments. Production can be backed up to S3 via stored procedure, then restored on pre-production servers. <a href="/assets/attachments/S3Restore.ps1_.txt">This PowerShell script</a> (called from Jenkins) automates pre-production data loading:

1. Drop existing databases (stored proc won't run if database exists)
2. Start restore for each database via stored proc
3. Extract task IDs from output using regex
4. Poll restore status until success or error
5. Exit on completion or failure

Great addition to RDS SQL Server, Amazon!
