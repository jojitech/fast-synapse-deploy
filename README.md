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
 - Retry / cool-down / backoff logic implemented starting from version 2.* for TooManyRequests (429) errors. 

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

    - uses: jojitech/fast-synapse-deploy@v2
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


## Throttle Configuration (v2+)

> ⚠️ **Requires task version 2 or later.** Earlier versions do not support configurable throttling.

FastSynapseDeploy automatically optimizes request throttling based on your deployment size. **Default settings work well for most scenarios** — only override when you have specific requirements.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SYNAPSE_DEPLOYMENT_SPEED` | `auto` | Controls throttling strategy: `auto`, `fast`, `safe`, or `yolo` |
| `SYNAPSE_MAX_CONCURRENT_REQUESTS` | `25` | Maximum parallel API requests |
| `SYNAPSE_REQUESTS_PER_MINUTE` | `0` (auto) | Hard RPM cap. Set to `0` for automatic calculation |

### Deployment Speeds

| Speed | Behavior |
|-------|----------|
| `auto` | **Recommended.** Adapts RPM limits based on artifact count |
| `fast` | 1.5x faster than auto. Higher risk of 429 throttling errors |
| `safe` | 0.6x slower than auto. Use for very large or sensitive deployments |
| `yolo` | No RPM limiting. Useful for testing  |

### Auto-Calculation Tiers

When using `auto` speed (default), RPM limits are calculated based on artifact count:

| Artifacts | RPM Limit |
|-----------|-----------|
| < 500 | Unlimited |
| 500 - 1000 | ~1100 |
| 1000 - 2000 | ~900 |
| 2000+ | ~700 |

> **Tip:** The tool automatically reduces RPM if it encounters 429 errors, so starting with defaults and letting it adapt is usually the best approach.

### Sample Rate Limit Event

```
##[warning]===================================================================
##[warning]  RATE LIMITED (429) - Event #1
##[warning]  [GET] [notebookOperationResults] opId:8bdff418
##[warning]  Pausing ALL requests for 5 minutes
##[warning]  Concurrent request limit reduced: 25 -> 18 (25% reduction)
##[warning]  RPM limit now: 700 | Speed: Yolo
##[warning]  Recommendation: Set SYNAPSE_MAX_CONCURRENT_REQUESTS=18 OR LOWER
##[warning]  Set SYNAPSE_DEPLOYMENT_SPEED=auto or lower (currently: yolo)
##[warning]===================================================================


```

### Sample Rate Limit Summary

```
##[warning]===========================================================================================
##[warning]  RATE LIMIT SUMMARY
##[warning]===========================================================================================
##[warning]  Total TooManyRequests (429) events: 1
##[warning]  Initial concurrent request limit: 25
##[warning]  Final concurrent request limit after backoffs: 18
##[warning]  RPM limit: unlimited
##[warning]
##[warning]  RECOMMENDATIONS:
##[warning]  Set SYNAPSE_MAX_CONCURRENT_REQUESTS=13 OR LOWER before the next run
##[warning]  and/or set SYNAPSE_REQUESTS_PER_MINUTE to a value to proactively throttle.
##[warning]  Consider using SYNAPSE_DEPLOYMENT_SPEED=auto or safe (currently: yolo)
##[warning]===========================================================================================
```

## Star Me
Please consider [leaving a star](https://github.com/marketplace/actions/fast-synapse-deploy) if your workspace was deployed faster!
Also [leave a comment](https://github.com/ShawnMcGough/fast-synapse-deploy/discussions/categories/general). I love to hear how it is helping with deployments!


## Release Notes

 - v2.0
   - major improvements to throttling / back-off
   - additional env variables to enable more control
   - more conservative defaults to prioritize success over raw speed

 - v1.0.1
   - bump packages

 - v1.0
   - Initial public release

## Enterprise and Support Options
This extension is free for personal and commercial use under the terms in LICENSE. For enterprise features, including:

- Source code access (under NDA)
- Security audits and certifications
- Custom modifications or integrations
- Ongoing support SLAs (e.g., priority bug fixes, updates)

Contact Jojitech LLC at info@jojitech.com