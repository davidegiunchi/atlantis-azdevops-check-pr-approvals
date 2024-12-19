# Atlantis Azure Devops check PR approvals

[Atlantis](https://www.runatlantis.io) is a Terraform Pull Request Automation platform, pretty everybody in your organization can modify terraform code and run plan and apply, that introduce some security/authorization problems that must be properly addressed.  
You can make the PR require an approvals by creating a server side configuration with *approved* requirements:
```
  plan_requirements: [approved]
  apply_requirements: [approved]
```
but *anybody* who can access and contribute to the repo, can approve it and this will fullfill the atlantis requirements.  
If you are using atlantis+github you can require the approve of a specific group with the [--gh-team-allowlist option](https://www.runatlantis.io/docs/server-configuration.html#gh-team-allowlist), that's a little better but this parameter is not present on atlantis for azure devops.  
I've created a shell script that connect to azure devops and check if the PR has been approved by a member of one or more groups, so you can make the PR require an *approve* by the devops/infrastructure team before the code can be executed in the plan or apply phase.  
You should make this script invoked by atlantis during a custom workflow, this will reject a PR that has not been approved by a member of one or more specific groups.  

## System Requirements

You only need **curl** and **jq** installed. 

## Configuration

- Create a [server side repo configuration](https://www.runatlantis.io/docs/server-side-repo-config.html) with a custom workflow that run check-pr-approvals.sh during the apply phase, example:
```
- id: /.*/
  branch: /.*/
  plan_requirements: []
  apply_requirements: [approved, undiverged]
  import_requirements: [approved, undiverged]
  workflow: custom
  allowed_overrides: []
  allowed_workflows: [custom]
  allow_custom_workflows: false
  delete_source_branch_on_merge: true
  repo_locking: true
  custom_policy_check: false
  policy_check: false
  autodiscover:
    mode: auto

workflows:
  custom:
    plan:
      steps:
      - init
      - plan
    apply:
      steps:
      - run: /home/atlantis/check-pr-approvals.sh
      - apply
```
Since [malicious code can be executed even during the plan phase](https://www.runatlantis.io/docs/security#protect-terraform-planning), if you prefer you can put the check-pr-approvals.sh invocation even during the *plan* phase. 

- Copy the check-pr-approvals.sh in the correct location:

```
cp check-pr-approvals.sh /home/atlantis/check-pr-approvals.sh
chmod 755 /home/atlantis/check-pr-approvals.sh
```

- Configure the script:

```
vi /home/atlantis/check-pr-approvals.sh
```
Modify the "Variables that must be set by human" section:
`AZURE_DEVOPS_ORG` your azure devops organization, usually something like *https://dev.azure.com/mycorporation* .
`AZURE_DEVOPS_PROJECT` the azure devops project name where there are your infrastructure's repos.
`REQUIRED_GROUPS` one or more azure devops group, one of the members of these groups must approve the PR to make the *atlantis apply* phase work.
`PAT` [Personal Access Token](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows) that can access to the infrastructure's repositories.


- Start atlantis with the server side repo configuration flag `--repo-config`, example:

```
ATLANTIS_AZUREDEVOPS_TOKEN="xyz"
atlantis server --atlantis-url="https://atlantis.mydomain.com" \
        --repo-allowlist="dev.azure.com/myorganization/myproject/infrastructure-repos-*" \
        --fail-on-pre-workflow-hook-error=true \
        --repo-config=/etc/atlantis.yaml \
```

- Check that [atlantis is working good](https://www.runatlantis.io/blog/2017/introducing-atlantis.html): create a PR with the required/optional approvers and try to run *atlantis apply* without any approvals, you should get an atlantis error. Then make the PR approved by one of the members of the *REQUIRED_GROUPS*, now the *atlantis apply* should work good and you shoud read something like this in the atlantis logs:

```
{"level":"info","ts":"2024-11-19T14:25:22.761Z","caller":"models/shell_command_runner.go:181","msg":"successfully ran 'sh -c' '/home/atlantis/check-pr-approvals.sh' in '/home/atlantis/.atlantis/repos/myorg/myproject/myrepo/156439/default'","json":{"repo":"myorg/myproject/myrepo","pull":"156439","duration":0.317727245}}
```

  
Don't mind to take a look to the [official atlantis documentation](https://www.runatlantis.io/docs/deployment.html#azure-devops) to configure atlantis and azuredevops to properly work together.  
Check the [security section of the atlantis doc](https://www.runatlantis.io/docs/security).
