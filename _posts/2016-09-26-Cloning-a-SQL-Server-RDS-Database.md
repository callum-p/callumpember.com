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
Cloning a database on the same RDS SQL Server instance presented challenges. Two approaches seemed obvious:

1. SSMS: right-click database → Tasks → Copy Database
2. S3 import/export feature

Neither works. SSMS fails due to missing privileges and wizard limitations. S3 import/export only allows one instance of the same database.

The solution: PowerShell scripting that replicates SSMS's Copy Database functionality. Requirements: master credentials and SQL Server PowerShell modules. The script uses SQL Server 2016 management tools paths but adapts to other versions.

RDS SQL Server quirk: Microsoft's scripts can't create ASPState databases (.NET session storage). While modifiable, it's simpler to restore an existing ASPState backup. However, ASPState stored procedures contain hardcoded database names that break in cloned databases. The script includes a fix for this.

Example usage:

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
