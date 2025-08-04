---
layout: post
title:  "Consul Import/Export or Backup/Restore"
image: ''
date: 2016-10-26 15:11:01
tags:
- Consul
- Backup
- Restore
description: ''
categories:
- Consul
---
I needed to export my Consul K/V store, delete the cluster, then restore the data. Finding no ready-made solutions, I initially did it manually for ~15 entries. After repeating this process several times, I wrote a script (and fixed auto-scaling nodes to leave gracefully).

Python code for Consul backup/restore:

{% highlight python %}
import json
import argparse
import requests
import sys
from base64 import b64decode

parser = argparse.ArgumentParser()
parser.add_argument('--backup', help = 'Backup the consul K/V store to file', action = 'store_true')
parser.add_argument('--restore', help = 'Restore the consul file to the server', action = 'store_true')
parser.add_argument('--host', help = 'Specify the consul host to use', required = True)
parser.add_argument('--file', help = 'Specify the file to backup/restore to', required = True)
parser.add_argument('--verbose', help = 'Print debug information', action = 'store_true')
args = parser.parse_args()

def main():
  if args.backup:
    backup()

  if args.restore:
    restore()

def restore():
  if args.verbose:
    print 'Restoring'

  base_url = '%s/v1/kv' % args.host

  if args.verbose:
    print 'Opening %s for reading...' % args.file

  with open(args.file) as f:
    data = json.load(f)

  for obj in data:
    val = b64decode(obj['Value'])
    url = "%s/%s" % (base_url, obj['Key'])

    if args.verbose:
      print 'Putting %s to %s...' % (val, url)

    r = requests.put(url, val)
    if args.verbose:
      print 'Consul response: %s' % r.text

  if args.verbose:
    print 'Restore complete'

def backup():
  if args.verbose:
    print 'Backing up...'

  url = "%s/v1/kv/?recurse&pretty" % args.host
  if args.verbose:
    print 'Getting %s' % url

  data = requests.get(url)
  if data.status_code != 200:
    print 'Invalid resposne code received from Consul.  Expected 200, got %d' % data.status_code
    sys.exit(1)

  if args.verbose:
    print 'Saving JSON output to %s' % args.file

  with open(args.file, 'w') as f:
    f.write(data.text)

  if args.verbose:
    print 'Backup finished.'

main()
{% endhighlight %}

Usage:
{% highlight python %}
python consul.py  --host http://consul.domain.internal:8500 --file out.json --backup --verbose
python consul.py  --host http://consul.domain.internal:8500 --file out.json --restore --verbose
{% endhighlight %}
