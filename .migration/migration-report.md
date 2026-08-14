# Azure DevOps to GitHub Actions Migration Report

## Scope

Pilot repository: `vsharma4142/AzurePipelinesSamples`

Central reusable workflows: `vsharma4142/github-actions-templates`

This pilot implements the target enterprise GitHub Actions pattern and demonstrates the migration on the `ApiE2ETestsWithDocker` application. The repository contains more than one Azure pipeline, so additional application workflows can be generated from the same agent/reusable-workflow pattern.

## Source Azure Pipelines discovered

- `ApiE2ETestsWithDocker/azure-pipelines.yml`
- `Library/azure-pipelines.yml`
- `Library/jobs/job_1_build_with_multiple_os.yml`
- `Library/jobs/job_2_test_with_different_postgres_versions.yml`
- `Library/jobs/job_publish_nuget.yml`
- `Library/jobs/job_contract_tests_with_client_apps.yml`

## Application selected for pilot

`ApiE2ETestsWithDocker`

Detected project characteristics:

- SDK-style ASP.NET Core application.
- `ApiE2ETestsWithDocker/WebApi/WebApi.csproj` targets `netcoreapp3.1`.
- `ApiE2ETestsWithDocker/WebApi.Tests/WebApi.Tests.csproj` targets `netcoreapp3.1` and references `coverlet.collector`.
- Existing Azure YAML currently contains only placeholder script steps; the application repository itself is therefore used to derive the actual build/test shape.

The requested enterprise migration agent is designed to support .NET Framework, .NET 6, .NET 8, and other SDK-style .NET repositories. This particular sample is older (`netcoreapp3.1`) and is retained as-is for source fidelity rather than silently upgrading application code.

## Generated GitHub Actions workflow

`.github/workflows/api-e2e-dotnet-ci-cd.yml`

The caller consumes reusable workflows from `vsharma4142/github-actions-templates` and implements:

- build
- unit tests
- Cobertura/coverlet line-coverage gate
- Checkmarx gate
- Snyk gate
- Nexus IQ gate
- immutable artifact versioning
- Artifactory publication
- Development deployment from `development`
- QA -> Staging -> Production promotion from `release/**`
- GitHub Environment based approval points
- Vault secret-reference resolution
- Ansible Tower/AAP IIS deployment
- endpoint health validation

Feature branches and pull requests cannot reach deployment jobs.

## Configurable quality gates

Repository/organization variables:

- `UNIT_TEST_COVERAGE_MIN` (default 80)
- `MAX_HIGH_VULNERABILITIES` (default 0)
- `MAX_CRITICAL_VULNERABILITIES` (default 0)
- `ARTIFACT_VERSION_PREFIX`
- `ARTIFACTORY_REPOSITORY`

The reusable CI workflow also accepts configurable enterprise wrapper command names for Checkmarx, Snyk, Nexus IQ, and Artifactory. This is intentional because the supplied reusable-workflow repository did not already contain Checkmarx, Snyk, Nexus IQ, Artifactory, Vault, or Tower integrations, and the exact installed enterprise action/wrapper interfaces were not present in the source repositories.

## Environment configuration variables

For each environment configure the corresponding repository/organization variables (or adapt the reusable workflow to your existing organization variable conventions):

- `<ENV>_TOWER_JOB_TEMPLATE`
- `<ENV>_VAULT_ROLE`
- `<ENV>_VAULT_SECRET_PATH`
- `<ENV>_IIS_SITE_NAME`
- `<ENV>_IIS_APP_POOL`
- `<ENV>_IIS_PHYSICAL_PATH`
- `<ENV>_IIS_HOST_NAME`
- `<ENV>_HTTPS_PORT`
- `<ENV>_SSL_CERTIFICATE_REF`
- `<ENV>_AUTHENTICATION_MODE`
- `<ENV>_HEALTH_URL`
- `<ENV>_CONFIG_JSON`

Where `<ENV>` is `DEV`, `QA`, `STAGING`, or `PROD`.

## Classic Release status

**UNRESOLVED SOURCE INPUT:** no Azure DevOps Classic Release URL or exported Release definition was provided for this repository.

Because of that, this pilot does not claim to have reproduced the repository's actual Classic Release stages, task groups, variable groups, approvals, IIS values, or deployment conditions. Instead, it implements the enterprise CD skeleton requested by the migration standard.

For an exact CD migration, supply either:

1. the Azure DevOps Classic Release definition URL containing `definitionId`, or
2. an exported Release definition JSON.

The migration factory should store that source as `.migration/ado-release-definition.json`, run GitHub Actions Importer for the release definition, and then let `.github/agents/ado-dotnet-migrator.agent.md` reconcile the raw Release definition, Importer output, and repository source.

## GitHub Actions Importer scaffolding

Custom runner transformer:

`.migration/transformers/runner-mappings.rb`

Example CI dry run from repository root:

```bash
gh actions-importer dry-run azure-devops pipeline \
  --source-file-path ApiE2ETestsWithDocker/azure-pipelines.yml \
  --custom-transformers .migration/transformers/*.rb \
  --output-dir .migration/importer-ci
```

Example Classic Release dry run after the definition ID is known:

```bash
gh actions-importer dry-run azure-devops release \
  --pipeline-id <release-definition-id> \
  --custom-transformers .migration/transformers/*.rb \
  --output-dir .migration/importer-release
```

## Approval model

Create/protect these GitHub Environments:

- `development`: no manual approval required
- `qa`: required reviewer(s)
- `staging`: required reviewer(s)
- `production`: required reviewer(s), ideally prevent self-review

The generated deployment reusable workflow declares the selected GitHub Environment at job level; environment protection rules therefore become the human-in-the-loop control.

## Deployment contract expected from Tower/AAP

The reusable deployment workflow sends the Tower job template the immutable artifact coordinates, Vault secret reference, IIS parameters, environment configuration, and an explicit deployment flow indicating:

1. create site if missing
2. back up current site
3. stop site and application pool
4. download the approved artifact
5. deploy it
6. perform environment substitution
7. configure authentication
8. configure HTTPS certificate
9. start application pool/site
10. health check
11. rollback on failure

The concrete implementation of these operations remains inside the existing enterprise Tower/AAP job template as requested; GitHub Actions orchestrates rather than RDPing directly to the server.

## Security notes

- No secret values were copied from Azure pipelines into GitHub workflow files.
- The migration uses Vault references rather than plaintext deployment credentials.
- The artifact is built once and the same artifact URI/version is passed into Development/QA/Staging/Production deployment jobs.
- The PAT pasted into the chat was not used. It should be revoked/rotated because it was disclosed in plaintext.

## Next validation needed in your environment

Before merging to the default branches:

1. Map the generic enterprise wrapper names to the actual Checkmarx/Snyk/Nexus IQ/Artifactory/Vault/Tower commands or replace those steps with your existing reusable actions.
2. Configure the required repository/organization variables.
3. Configure the four GitHub Environments and reviewers.
4. Provide the actual Classic Release URL so its CD configuration can be migrated rather than represented by the generic target pattern.
5. Execute the pilot workflow on your runner infrastructure and validate scanner exit codes, Artifactory URI output, Tower extra-vars schema, IIS rollback, and endpoint validation.
