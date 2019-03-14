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

One of the problems most Kubernetes administrators will eventually face is protecting an Ingress from public access. There are a number of ways to do this, including IP whitelisting, TLS authentication, use an internal only service for the ingress controller, and many more.

One of my favorite ways is to use [oauth2_proxy](https://github.com/pusher/oauth2_proxy). I've used it a number of times over the years, but there was always a drawback that bothered me - with the [documented setup](https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/auth/oauth-external-auth) and other countless examples online, they use a deployment of the oauth2_proxy container per deployment/service/ingress that the user is wanting to protect. Although the resource footprint of oauth2_proxy is small, that is needless waste.

Now, onto some oauth2_proxy details. You can use various different providers, like GitHub, Google, GitLab, LinkedIn, Azure and Facebook. What's one thing nearly every developer in the world has in common? They almost certainly have a GitHub account, so that's what I use as a provider normally.  There are some strict rules though around GitHub OAuth2 and redirection:

![GitHub OAuth2 Redirection rules](/assets/attachments/github-oauth2/github-oauth-redirection-rules.png)

What this means is that if you are using oauth2_proxy as-is, you need a separate deployment for each domain you want to secure.

> But I want to secure https://prometheus.mydomain.com, https://grafana.mydomain.com and https://alertmanager.mydomain.com. So I need separate deployments of oauth2_proxy for that?

Out of the box, sadly yes. But with a slight modification of the deployment, we can use a single oauth2_proxy instance for any domain we want. To do this we do the following:

- Attach an nginx sidecar container to the oauth2_proxy deployment. This container will redirect to anything after `/redirect/` in the request URI.
- Make the oauth2_proxy have it's own domain
- Add an upstream to oauth2_proxy for the /redirect path
- Set the cookie domain in oauth2_proxy to include all subdomains
- Setup a GitHub OAuth2 app and point it at the oauth2_proxy domain
- In the ingresses that we want to protect, use the following annotations (replace $DNS_ZONE_INTERNAL with your own domain):

{% highlight yaml %}
---
nginx.ingress.kubernetes.io/auth-url: "https://oauth2.$DNS_ZONE_INTERNAL/oauth2/auth"
nginx.ingress.kubernetes.io/auth-signin: "https://oauth2.$DNS_ZONE_INTERNAL/oauth2/start?rd=/redirect/$http_host$request_uri"

{% endhighlight %}


### oauth2_proxy deployment:

Here is a full, working (at least in my cluster) deployment spec for oauth2_proxy with the nginx sidecar.

If you want to use it, you'd need to replace all the variables. I personally use envsubst in my deployment pipelines for this. The variables that need replacing are `$DNS_ZONE_INTERNAL` `$OAUTH2_CLIENT_ID` `$OAUTH2_CLIENT_SECRET` and you would want to set your GitHub org.

[Full Deployment Spec](/assets/attachments/github-oauth2/full-deployment.yml)


### Ingress example

Once you've got the deployment above working, you can protect an ingress like so (key takeaways are the annotations):

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
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2.$DNS_ZONE_INTERNAL/oauth2/start?rd=/redirect/$http_host$request_uri"
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


Hopefully this saves you some resources in your cluster and some time creating multiple oauth2_proxy deployments!
