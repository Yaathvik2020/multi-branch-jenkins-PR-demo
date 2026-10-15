# Jenkins Multibranch + Pull Request Demo

A small Java app and a ready-made local Jenkins that shows the full pull request flow:

| Event | What Jenkins does |
|---|---|
| Push to a feature branch | Build + Test |
| Open a **Pull Request** | Build + Test (PR merged with target branch). **No deploy.** Status shown on the PR |
| Merge to `develop` | Build + Test + Docker build + **Deploy to DEV** (http://localhost:8081) |
| Merge to `main` | Build + Test + Docker build + **approval** + **Deploy to PROD** (http://localhost:8082) |

## Project layout

```
jenkins-pr-demo/
├── app/                        <- push THIS folder's content as your GitHub repo
│   ├── Jenkinsfile             <- the pipeline (stages + PR rules)
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/ (App, Calculator + unit tests)
├── jenkins/                    <- local Jenkins, already configured as code
│   ├── Dockerfile              <- Jenkins + Maven + Docker CLI
│   ├── plugins.txt
│   ├── docker-compose.yml
│   ├── .env.example
│   └── casc/
│       ├── jenkins.yaml            <- admin user + GitHub credentials
│       └── multibranch-job.groovy  <- creates the Multibranch job with PR discovery
└── scripts/
    ├── create-webhook.sh       <- GitHub webhook (push + pull_request)
    ├── branch-protection.sh    <- block merge unless Jenkins passes
    └── demo-flow.sh            <- creates a passing or failing PR for you
```

## What you need

- Docker (with Docker Compose)
- Git and a GitHub account
- GitHub CLI `gh` (optional but makes this easier): https://cli.github.com
- ngrok (optional, only for instant webhooks)

---

## Step 1: Create the GitHub repo from the `app/` folder

```bash
cd jenkins-pr-demo/app
git init -b main
git add .
git commit -m "Initial commit"

# create an empty repo on GitHub named jenkins-pr-demo-app, then:
git remote add origin https://github.com/<your-user>/jenkins-pr-demo-app.git
git push -u origin main

# create the develop branch too
git checkout -b develop
git push -u origin develop
```

Or with the GitHub CLI: `gh repo create jenkins-pr-demo-app --public --source=. --push`

## Step 2: Create a GitHub token

GitHub -> Settings -> Developer settings -> Personal access tokens -> Tokens (classic) -> Generate.

Tick: `repo` and `admin:repo_hook`. Copy the token.

## Step 3: Start Jenkins

```bash
cd jenkins-pr-demo/jenkins
cp .env.example .env
# edit .env: set GITHUB_OWNER, GITHUB_REPO, GITHUB_USER, GITHUB_TOKEN
docker compose up -d --build
```

First start takes a few minutes (downloads plugins). Watch progress:

```bash
docker compose logs -f jenkins
```

Open http://localhost:8080 and log in with `admin` / the `ADMIN_PASSWORD` from `.env`.

You should already see a job called **demo-app**. Open it. Jenkins scans the repo and shows `main` and `develop`.

## Step 4 (optional): Webhook for instant builds

Without a webhook, Jenkins checks GitHub **every 1 minute**, so the demo still works. For instant builds, GitHub must be able to reach Jenkins:

```bash
ngrok http 8080
# copy the https URL, e.g. https://abcd-12-34.ngrok-free.app
```

Put that URL in `jenkins/.env` as `JENKINS_URL=https://abcd-12-34.ngrok-free.app/`, then restart: `docker compose up -d`.

Create the webhook:

```bash
cd jenkins-pr-demo/scripts
./create-webhook.sh <your-user> jenkins-pr-demo-app https://abcd-12-34.ngrok-free.app
```

Check: GitHub repo -> Settings -> Webhooks -> Recent Deliveries should show a green tick.

## Step 5: Run the demo

Run from inside your cloned app repo (the `app/` folder).

### A. Passing PR

```bash
../scripts/demo-flow.sh pass
```

What happens:
1. A new branch is pushed. Jenkins creates a job for it and builds.
2. A PR is opened. Jenkins creates **PR-1** and runs Build, Unit Tests, Package.
3. **Docker Build and Deploy stages are skipped** (a PR never deploys).
4. The PR page in GitHub shows `continuous-integration/jenkins/pr-merge` with a green tick.

In the PR build console you will see:
```
=== PULL REQUEST #1: Add subtract method
=== From 'feature-pass-123456' into 'develop'
```

### B. Failing PR

```bash
../scripts/demo-flow.sh fail
```

A unit test now fails, so the PR shows a red X. Fix the test and push again: Jenkins rebuilds the same PR automatically.

### C. Merge to develop (deploy to DEV)

Merge the passing PR:

```bash
gh pr merge 1 --merge
```

Jenkins builds `develop`, builds the Docker image and deploys it.

```bash
curl http://localhost:8081
# Hello from demo-app! Environment: DEV
```

### D. Release to PROD

```bash
gh pr create --base main --head develop --title "Release" --body "Release to prod"
gh pr merge <number> --merge
```

The `main` build pauses at **Approval for PROD**. Open the build in Jenkins and click **Deploy**.

```bash
curl http://localhost:8082
# Hello from demo-app! Environment: PROD
```

## Step 6 (optional): Block merging when Jenkins fails

Run this **after** the first PR build (the check name only exists after Jenkins reports once):

```bash
cd jenkins-pr-demo/scripts
./branch-protection.sh <your-user> jenkins-pr-demo-app
```

Now a PR with a red X cannot be merged.

---

## Which stages run for each build

| Stage | PR-1 | feature branch | develop | main |
|---|---|---|---|---|
| Build Info, Build, Unit Tests, Package | Yes | Yes | Yes | Yes |
| Docker Build | No | No | Yes | Yes |
| Deploy to DEV | No | No | Yes | No |
| Approval + Deploy to PROD | No | No | No | Yes |

## Where the key ideas are in the code

| Idea | File and place |
|---|---|
| PR discovery switched on | `jenkins/casc/multibranch-job.groovy` -> `buildOriginPRMerge(true)` |
| PR details (`CHANGE_ID` etc.) | `app/Jenkinsfile` -> stage `Build Info` |
| PRs never deploy | `app/Jenkinsfile` -> `when { not { changeRequest() } ... }` |
| Credentials stored securely | `jenkins/casc/jenkins.yaml` + `.env` (not in Git) |
| Backup scan every minute | `multibranch-job.groovy` -> `periodicFolderTrigger` |

## Troubleshooting

| Problem | Fix |
|---|---|
| Job `demo-app` not created | `docker compose logs jenkins`. Check `.env` values and that the Job DSL plugin installed |
| Job DSL error: unknown method | Plugin versions differ. Create the Multibranch job once in the UI (Branch source: GitHub, Behaviours: discover branches and PRs from origin, merge with target) |
| No `PR-1` job | Open the job -> **Scan Multibranch Pipeline Now** -> **Scan Log** |
| `mvn` or `docker` not found | Rebuild the image: `docker compose build --no-cache` |
| Docker permission denied | The compose file runs Jenkins as root for this demo. Keep that line |
| Webhook red in Recent Deliveries | ngrok URL changed or missing trailing `/github-webhook/` |
| No status on the PR | Token needs the `repo` scope, and `JENKINS_URL` must be correct |
| Port 8081 / 8082 already used | Change the ports in the Jenkinsfile |

## Clean up

```bash
cd jenkins-pr-demo/jenkins
docker compose down -v
docker rm -f demo-app-dev demo-app-prod
```

> Demo only: Jenkins runs as root with the host Docker socket mounted. Do not use this setup in production.
