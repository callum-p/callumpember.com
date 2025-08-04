---
layout: post
title:  "Easy Kubernetes Nginx Ingress Custom Error Pages"
image: ''
date: 2020-07-21 14:03:00
tags:
- Kubernetes
- Ingress
- Nginx-ingress
description: 'The easiest way to setup custom error pages for Nginx ingress on Kubernetes'
categories:
- Kubernetes
- Ingress
---

Kubernetes resources showed different outage pages than EC2 resources due to ingress-nginx.

While some suggest deploying Docker containers for error pages, there's a simpler solution—add this to your ingress:

```yaml
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/server-snippet: |
      location @custom_503 {
        return 503 "<html> <head> <meta http-equiv='Content-Type' content='text/html; charset=UTF-8'> <style>...</style> </head> <body> <div class='container'> <div class='content'> <div class='title'> We apologise for the inconvenience. </div><div class='title'> Please try again in 10 minutes. </div><div> <p> We work hard to make xx the world's best xx software. Occasionally, downtime is required to deliver new features and improvements to you. </p></div></div></div></body></html>";
      }
      error_page 503 @custom_503;

```

![Custom 503](/assets/attachments/custom503.png)
