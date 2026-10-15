// Creates the Multibranch Pipeline job with branch + pull request discovery
def owner = System.getenv('GITHUB_OWNER')
def repo  = System.getenv('GITHUB_REPO')

multibranchPipelineJob('demo-app') {
  displayName('demo-app')
  description('Multibranch pipeline: branches and pull requests')

  branchSources {
    github {
      id('demo-app-github')                  // unique id, do not change later
      scanCredentialsId('github-creds')
      repoOwner(owner)
      repository(repo)
      repositoryUrl("https://github.com/${owner}/${repo}.git")

      buildOriginBranch(true)                // normal branches (main, develop, feature-*)
      buildOriginBranchWithPR(false)         // skip a branch build if it already has a PR
      buildOriginPRMerge(true)               // PR from same repo, tested merged with target branch
      buildOriginPRHead(false)
      buildForkPRMerge(false)                // PRs from forks (turn on if needed)
      buildForkPRHead(false)
    }
  }

  factory {
    workflowBranchProjectFactory {
      scriptPath('Jenkinsfile')
    }
  }

  // Backup scan every minute so the demo works even without a webhook
  triggers {
    periodicFolderTrigger {
      interval('1m')
    }
  }

  // Remove jobs for deleted branches and closed PRs
  orphanedItemStrategy {
    discardOldItems {
      daysToKeep(7)
      numToKeep(20)
    }
  }
}
