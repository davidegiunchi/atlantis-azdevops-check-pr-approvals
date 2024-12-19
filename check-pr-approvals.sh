#!/bin/bash

# Variables that must be set by human
AZURE_DEVOPS_ORG="https://dev.azure.com/XXX_ORGANIZATION_NAME_XXX"               # azdevops organization name
AZURE_DEVOPS_PROJECT="xxx_project_name_xxx"                                      # azdevops project with repos contained
REQUIRED_GROUPS=("xxx_first_required_group_xxx" "xxx second required group xxx") # the PR must be approved by one of this group's member
PAT="xxx_pat_token_xxx"                                                          # azdevops pat token, the user must access all the repos where the PR can be created

# variables automatically fullfilled by atlantis
PR_ID=$PULL_REQUEST_ID
REPOSITORY=$BASE_REPO_NAME

# Fetch pull request details
PR_DETAILS=$(curl -s \
  -u ":$PAT" \
  -H "Content-Type: application/json" \
  "$AZURE_DEVOPS_ORG/$AZURE_DEVOPS_PROJECT/_apis/git/repositories/$REPOSITORY/pullrequests/$PR_ID?api-version=6.0")

# Extract approvers, value[] can be present or not
APPROVERS=$(echo "$PR_DETAILS" | jq -r 'if .value? then
    .value[].reviewers[] | select(.vote == 10) | .uniqueName
  else
    .reviewers[] | select(.vote == 10) | .uniqueName
  end
')

# Check if at least one required group is present
APPROVAL_FOUND=false
for GROUP in "${REQUIRED_GROUPS[@]}"; do
  if echo "$APPROVERS" | grep -q "$GROUP"; then
    APPROVAL_FOUND=true
    echo "Approval check passed for group: $GROUP"
    break
  fi
done

# Exit with appropriate status
if [ "$APPROVAL_FOUND" = true ]; then
  exit 0
else
  echo "Approval check failed. None of the required groups have approved."
  exit 1
fi
