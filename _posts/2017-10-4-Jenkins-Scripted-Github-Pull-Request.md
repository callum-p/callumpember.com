---
layout: post
title:  "Jenkins Scripted Pipeline GitHub Pull Requests"
image: ''
date:   2017-10-04 00:06:31
tags:
- Jenkins
- GitHub Pull Request Builder
- Pipeline
description: 'How to use GHPRB with a scripted Jenkins Pipeline'
categories:
- Jenkins
---

**Update: Consider using GitHub organization with multi-branch pipelines instead of GHPRB.**

Converting Jenkins jobs to scripted pipelines revealed that GHPRB plugin documentation only covers declarative pipelines. Google searches yielded GitHub issues but no working examples. Here's a functional Jenkins scripted pipeline with GHPRB:

{% highlight java linenos %}
#!/bin/groovy
import org.kohsuke.github.GHCommitState;

node {
  try {
    properties([
      buildDiscarder(logRotator(artifactNumToKeepStr: '20', numToKeepStr: '20')),
      parameters([
        string(name: 'GIT_REPO', defaultValue: 'git@github.com:MyOrg/UI.git', description: 'Git repo'),
        [$class: 'GitParameterDefinition', branch: 'origin/master', branchFilter: '.*', defaultValue: '', description: 'Git tag', name: 'TAG', quickFilterEnabled: false, selectedValue: 'NONE', sortMode: 'DESCENDING_SMART', tagFilter: '*', type: 'PT_TAG'],
      ]),
      [$class: 'GithubProjectProperty', displayName: '', projectUrlStr: 'https://github.com/MyOrg/UI/'],
      [$class: 'org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty', triggers:[
        [
          $class: 'org.jenkinsci.plugins.ghprb.GhprbTrigger',
          orgslist: 'MyOrg',
          cron: 'H/5 * * * *',
          triggerPhrase: 'special trigger phrase',
          onlyTriggerPhrase: true,
          useGitHubHooks: true,
          permitAll: true,
          autoCloseFailedPullRequests: false,
          displayBuildErrorsOnDownstreamBuilds: true,
          extensions: [
            [
              $class: 'org.jenkinsci.plugins.ghprb.extensions.status.GhprbSimpleStatus',
              commitStatusContext: 'Docker Build',
              showMatrixStatus: false,
              triggeredStatus: 'Starting job...',
              startedStatus: 'Building...',
              completedStatus: [
                [$class: 'org.jenkinsci.plugins.ghprb.extensions.comments.GhprbBuildResultMessage', message: 'Done', result: GHCommitState.SUCCESS],
                [$class: 'org.jenkinsci.plugins.ghprb.extensions.comments.GhprbBuildResultMessage', message: 'Failed', result: GHCommitState.FAILURE]
              ]
            ]
          ]
        ]
      ]]
    ])

    stage('Checkout') {
      checkout([$class: 'GitSCM', branches: [[name: 'origin/master']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'MyOrg github', url: params.GIT_REPO]]])
    }
  } catch (Exception ex) {
    currentBuild.result = 'FAILURE'
    echo ex.toString()

    // Throw RejectedAccessException again if its a script privilege error
    if (ex.toString().contains('RejectedAccessException')) {
      throw ex
    }
  }
}
{% endhighlight %}

Note: Expect Jenkins sandbox security warnings. Approve them at https://jenkins.yourorg.com/scriptApproval/
