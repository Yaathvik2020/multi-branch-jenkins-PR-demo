#!/bin/bash
# Run this INSIDE your cloned app repo.
# Usage:  ./demo-flow.sh pass     -> opens a PR with a good change (green check)
#         ./demo-flow.sh fail     -> opens a PR with a broken test (red X)
set -e
MODE=${1:-pass}
BRANCH="feature-$MODE-$(date +%H%M%S)"

git checkout develop
git pull origin develop
git checkout -b "$BRANCH"

if [ "$MODE" = "pass" ]; then
  # add a harmless new method + test
  sed -i 's#^}$#    public int subtract(int a, int b) { return a - b; }\n}#' src/main/java/com/example/Calculator.java
  sed -i 's#^}$#    @Test\n    void subtractsTwoNumbers() { assertEquals(1, calc.subtract(3, 2)); }\n}#' src/test/java/com/example/CalculatorTest.java
  MSG="Add subtract method"
else
  # break a test on purpose
  sed -i 's#assertEquals(5, calc.add(2, 3))#assertEquals(99, calc.add(2, 3))#' src/test/java/com/example/CalculatorTest.java
  MSG="Broken test (demo of failing PR)"
fi

git add .
git commit -m "$MSG"
git push origin "$BRANCH"
gh pr create --base develop --head "$BRANCH" --title "$MSG" --body "Demo PR ($MODE)"
echo "PR created. Watch Jenkins: http://localhost:8080/job/demo-app/"
