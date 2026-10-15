#!/bin/bash
# Blocks merging a PR unless the Jenkins check passed and 1 reviewer approved.
# Run AFTER the first PR build (the check name only exists after Jenkins reports once).
# Usage: ./branch-protection.sh <owner> <repo>
set -e
OWNER=${1:?owner}
REPO=${2:?repo}

cat > /tmp/protection.json <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["continuous-integration/jenkins/pr-merge"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null
}
JSON

for BRANCH in main develop; do
  gh api "repos/$OWNER/$REPO/branches/$BRANCH/protection" --method PUT --input /tmp/protection.json
  echo "Protection applied to $BRANCH"
done
