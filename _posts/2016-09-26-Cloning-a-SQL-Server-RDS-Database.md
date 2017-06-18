---
layout: post
title:  "Cloning a SQL Server RDS Database"
image: ''
date: 2016-09-26 08:19:11
tags:
- AWS
- RDS
description: ''
categories:
- RDS
---
A hurdle I encountered recently was cloning a database on the same RDS SQL Server. There are a few ways I thought this could be accomplished:

1. In SSMS, right click on the database->Tasks->Copy Database
2. Use the S3 import/export feature

Unfortunately neither of these methods will work in RDS due to various nuances. The first method won’t work due to a missing privilege and the way the copy database wizard creates databases. The second method won’t work because you can only have one of the same database with the S3 import/export feature.

To get around this, we can use powershell to script the Copy Database feature that SSMS uses. The only requirement (besides the obvious master username/password) is to have the SQL Server powershell modules installed. For the script I’ve provided here, I’m using the SQL Server 2016 management tools installation and the import path reflects that. It can be altered to support whatever version you have installed.

Slightly off the main point of this blog post, but another nuance of RDS SQL Server is that you can’t use the MS provided scripts to create an ASPState database (.Net session storage). You can hack the script to get it to work, but for me it is easier to just restore a backup of an existing ASPState database. Unfortunately the ASPState database has a bunch of stored procedures that have the database name hardcoded, so when you clone the ASPState database, it won’t actually work because the SPs will fail. I’ve included a cmdlet in the supplied script to get around this.

An example of calling the cmdlets would be:

{% highlight powershell %}
if (! (Database-Exists -Username $user -Password $pass -Server $server -Database $newdb)) {
   Create-Database -Username $user -Password $pass -Server $server -Database $newdb | Out-Null
   Copy-Database -Username $user -Password $pass -Server $server -SourceDatabase $db -TargetDatabase $newdb
   if ($newdb -like "*ASPState*") {
     Fix-ASPState -Username $user -Password $pass -Server $server -OldDatabase $db -NewDatabase $newdb
   }
}
{% endhighlight %}

<a href="/assets/attachments/CloneDB.ps1_.txt">The script can be downloaded here.</a>
