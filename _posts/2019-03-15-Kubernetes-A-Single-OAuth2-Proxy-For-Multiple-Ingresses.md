---
layout: post
title:  "Kubernetes: A single OAuth2 proxy for multiple ingresses"
image: ''
date: 2019-03-15 10:14:09
tags:
- Kubernetes
description: 'Use a single OAuth2 proxy (via GitHub) to protect multiple ingresses'
categories:
- Kubernetes
---

Protecting Kubernetes Ingresses from public access has several options: IP whitelisting, TLS authentication, internal-only ingress controllers.

I prefer [oauth2_proxy](https://github.com/pusher/oauth2_proxy). The [documented setup](https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/auth/oauth-external-auth) deploys separate oauth2_proxy containers per ingress—wasteful despite the small footprint.

oauth2_proxy supports GitHub, Google, GitLab, LinkedIn, Azure, and Facebook. I use GitHub since most developers have accounts. However, GitHub OAuth2 enforces strict redirection rules:

![GitHub OAuth2 Redirection rules](/assets/attachments/github-oauth2/github-oauth-redirection-rules.png)

This requires separate oauth2_proxy deployments per domain.

> To secure https://prometheus.mydomain.com, https://grafana.mydomain.com and https://alertmanager.mydomain.com—do I need three oauth2_proxy deployments?

By default, yes. But with modifications, one oauth2_proxy can protect multiple domains:

- Add nginx sidecar that redirects to URLs after `/redirect/` in the request
- Assign oauth2_proxy its own domain
- Configure upstream for /redirect path
- Set cookie domain to include all subdomains
- Create GitHub OAuth2 app for oauth2_proxy domain
- Apply these ingress annotations (replace $DNS_ZONE_INTERNAL):

{% highlight yaml %}
---
nginx.ingress.kubernetes.io/auth-url: "https://oauth2.$DNS_ZONE_INTERNAL/oauth2/auth"
nginx.ingress.kubernetes.io/auth-signin: "https://oauth2.$DNS_ZONE_INTERNAL/oauth2/start?rd=/redirect/$http_host$request_uri"

{% endhighlight %}


### oauth2_proxy deployment:

Working deployment with nginx sidecar. Replace `$DNS_ZONE_INTERNAL`, `$OAUTH2_CLIENT_ID`, `$OAUTH2_CLIENT_SECRET`, and GitHub org. Use envsubst for variable substitution.

[Full Deployment Spec](/assets/attachments/github-oauth2/full-deployment.yml.txt)

### Ingress example

Once the deployment is working, protect ingresses using these annotations:

{% highlight yaml %}
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: prometheus
  namespace: istio-system
  labels:
    app: prometheus
  annotations:
    kubernetes.io/ingress.class: "nginx-public"
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2.$DNS_ZONE_INTERNAL/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2.$DNS_ZONE_INTERNAL/oauth2/start?rd=/redirect/$http_host$escaped_request_uri"
spec:
  rules:
  - host: "prometheus.$DNS_ZONE_INTERNAL"
    http:
      paths:
      - path: /
        backend:
          serviceName: prometheus
          servicePort: http
{% endhighlight %}


This approach saves cluster resources and eliminates the need for multiple oauth2_proxy deployments!
