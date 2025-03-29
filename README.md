<table>
  <tr>
    <td><img src="icon.png" width="48" alt="icon"></td>
    <td><h1>Fast Synapse Deploy</h1></td>
  </tr>
</table>




## Overview
This action will deploy Azure Synapse artifacts, fast!

### Major Features
 - Optimized for speed using connection pooling and multiple async requests to the Synapse API.
 - Leverages Azure Login for authentication.
 - Supports HTTP_PROXY, HTTPS_PROXY, and NO_PROXY environment variables.
 - Can be combined with `validate` from [Microsoft action](https://github.com/marketplace/actions/synapse-workspace-deployment) (see note below).
 - Works on Linux or Windows runners.

## Pre-requisites for the action
Requires [Azure Login Action](https://github.com/marketplace/actions/azure-login) for authentication.

The YAML might look something like this:
```yaml

steps:
    - uses: actions/checkout@v4
    - name: Azure Login
    uses: azure/login@v2
    with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - uses: ShawnMcGough/fast-synapse-deploy@v1
    with:
        template: 'TemplateForWorkspace.json'
        parameters: 'TemplateParametersForWorkspace.json'
        subscription-id: '${{ secrets.AZURE_SUBSCRIPTION_ID }}'
        resource-group: 'synapse-rg'
        workspace-name: 'workspace'
        delete-artifacts: 'true' 

```

## Not Supported 
 - Deploying ManagedPrivateEndpoints.
 - Deploying *directly* from branch other than `publish`. 
   - However, can be combined with `validate` action (see note below) to achieve same result. 
 - Incremental deployment. Hopefully not needed given the speed optimizations!

## Should I use this action?
 - If the [official Microsoft action](https://github.com/marketplace/actions/synapse-workspace-deployment) doesn't meet your needs, give it a try. This action allows for more async requests, resulting in a faster deployment. 

## Combine with the Microsoft 'Validate' Action
This action can work in tandem with the Microsoft `validate` action, which is required to address a [known issue](https://learn.microsoft.com/en-us/azure/synapse-analytics/cicd/continuous-integration-delivery#1-publish-failed-workspace-arm-file-is-more-than-20-mb) with file size limit during publish. High level, you would first use `validate` to generate the required templates, then use this action to quickly deploy from those templates. 

## SYNAPSE_API_LIMIT
This action seeks to deploy artifacts as quickly as possible. To that end, it will make multiple concurrent requests to the Synapse API. Depending on usage patterns (multiple and/or frequent deployments, for example), the Synapse API might respond with `TooManyRequests [429]`. The `SYNAPSE_API_LIMIT` environment variable is used to limit the number of concurrent requests to try and mitigate this issue.  Unfortunately, the Synapse API does not implement a `retry-after` header, so the entire deploy must be terminated.

## Star Me
Please consider [leaving a star]() if your workspace was deployed faster!
Also [leave a comment](https://github.com/ShawnMcGough/fast-synapse-deploy/discussions/categories/general). I love to hear how it is helping with deployments!


## Release Notes

 - 1.0.12
   - Initial public release








