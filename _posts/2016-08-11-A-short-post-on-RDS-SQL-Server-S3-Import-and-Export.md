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
First things first, a big thumbs up to AWS for finally implementing this feature, and just ahead of doing a migration of my employers SQL Server to RDS too. To read up on the new feature <a href="http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/SQLServer.Procedural.Importing.html">click here</a>.

For using RDS SQL Server S3 Import/Export for its main use of migrations, it is perfect. I have a few other use cases for it though where it is slightly underwhelming. Some of the limitations I’ve encountered are:

1. Unable to use a SQL agent job to schedule backup / restores from S3. I talked to AWS support about this and they said there was an issue with passing through credentials with the SQL agent job.
2. The backup is several times larger than a regular SQL backup file. I’m 90% sure this is due to the type of backup that AWS’ stored procedure takes, but I haven’t investigated this further. I probably won’t update this post with my findings but we will see. Perhaps it copies the entire backup set, not just an individual backup. The biggest downside to this is that it makes my restores to pre-production and staging take a lot longer than it should.
3. You can only have 1 restored version of the database on the server at a time, no matter what it is named.

Moving away from the negatives, this new functionality has made my life a lot easier in terms of deployments to staging/pre-production environments. When I run a preproduction deployment I can now simply call the stored proc on the production database to backup to S3, then on the preproduction SQL server run the stored proc to load the database. <a href="/assets/attachments/S3Restore.ps1_.txt">Here is an example</a> of a powershell script called from Jenkins that loads my pre-production data.. The general idea behind the script is:

1. Iterate through a hash of database names and drop them from the server (because the stored proc won’t run if the database exists)
2. Iterate through the database names again and run the stored proc to start the restore
3. Get the task ID from the output of step 2 using regex (lame – this should be easier)
4. In a continuous loop, run the stored proc to query the restore status checking for success or error messages.  Exit on error.
5. Break once all databases have been restored successfully.

Overall great job Amazon!  I know what it’s like to polish a turd but you are doing a fantastic job with SQL server.
