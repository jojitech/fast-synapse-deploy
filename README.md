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

### TL;DR: Leave the Defaults...

**For most users, no configuration is needed.** FastSynapseDeploy automatically:
- Adjusts request rates based on your deployment size
- Backs off and retries when rate limits are hit
- Recovers gracefully from 429 errors

Just run the task and let it handle throttling for you.

### ...Unless you have the Need for Speed

**Many deployments can be deployed significantly faster** by setting `SYNAPSE_DEPLOYMENT_SPEED=yolo`. However, there is a greater chance of hitting rate limits (429 errors). These limits are not documented and appear to vary based on time of day and region.


### When to Change Settings

| Scenario | Recommended Action |
|----------|-------------------|
| **Deployments work fine** | Do nothing. Keep defaults. |
| **Frequent 429 errors / failures** | Set `SYNAPSE_DEPLOYMENT_SPEED=safe` |
| **Want maximum speed** | Set `SYNAPSE_DEPLOYMENT_SPEED=yolo` |
| **Need fine-grained control** | Set specific env variables (advanced) |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SYNAPSE_DEPLOYMENT_SPEED` | `auto` | Controls throttling strategy: `auto`, `fast`, `safe`, or `yolo` |
| `SYNAPSE_MAX_CONCURRENT_REQUESTS` | `25` | Maximum parallel API requests (overrides speed-based calculation) |
| `SYNAPSE_REQUESTS_PER_MINUTE` | `0` (auto) | Hard RPM cap. `0` = automatic based on artifact count |
| `SYNAPSE_COOLDOWN_SECONDS` | `150` | Wait time (seconds) after a 429 error. Range: 30-900 |

### Deployment Speeds

| Speed | Behavior | When to Use |
|-------|----------|-------------|
| `auto` | Balanced concurrency and RPM based on artifact count | **Default. Use this unless you have a reason not to.** |
| `safe` | Lower concurrency (15), conservative RPM limits | Experiencing frequent 429s or deployment failures |
| `fast` | Higher concurrency (37), 1.5× RPM limits | Comfortable with occasional 429s for faster deploys |
| `yolo` | Maximum concurrency (100), no RPM limit | Testing, off-peak deployments, or intentionally pushing limits |

### How Auto-Calculation Works

When using `auto` speed (default), the tool calculates RPM limits based on how many artifacts you're deploying:

| Artifacts | RPM Limit | Rationale |
|-----------|-----------|-----------|
| < 500 | Unlimited | Small deployments rarely hit limits |
| 500 - 1000 | ~1000 | Moderate throttling |
| 1000 - 2000 | ~800 | More conservative |
| 2000+ | ~500 | Large deployments need careful pacing |

If a 429 error occurs, the tool automatically:
1. Pauses all requests for the cooldown period
2. Reduces concurrency by 25%
3. Tightens RPM limits
4. Retries the failed request

This means **even if you start too aggressive, the tool will adapt**.

### Sample Rate Limit Event

```
##[warning]===================================================================
##[warning]  RATE LIMITED (429) - Event #1
##[warning]  [GET] [notebookOperationResults] opId:8bdff418
##[warning]  Pausing ALL requests for 2.5 minutes
##[warning]  Concurrent request limit reduced: 25 -> 18 (25% reduction)
##[warning]  RPM limit now: 700 | Speed: auto
##[warning]  Recommendation: Set SYNAPSE_MAX_CONCURRENT_REQUESTS=18 OR LOWER
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
##[warning]  RPM limit: unlimited -> 700
##[warning]
##[warning]  RECOMMENDATIONS:
##[warning]  Set SYNAPSE_MAX_CONCURRENT_REQUESTS=13 OR LOWER before the next run
##[warning]  and/or set SYNAPSE_REQUESTS_PER_MINUTE to a value to proactively throttle.
##[warning]===========================================================================================
```

> **Tip:** A TooManyRequests (429) event means your deployment had to pause and resume — adding time to your overall deployment. **Ideal deployments have zero 429 events.** If you consistently see rate limit events, consider using `SYNAPSE_DEPLOYMENT_SPEED=safe` or lowering `SYNAPSE_MAX_CONCURRENT_REQUESTS` to avoid the delays caused by cooldown periods.


## Star Me
Please consider [leaving a star](https://github.com/marketplace/actions/fast-synapse-deploy) if your workspace was deployed faster!
Also [leave a comment](https://github.com/ShawnMcGough/fast-synapse-deploy/discussions/categories/general). I love to hear how it is helping with deployments!


## Release Notes

 - v2.0
   - major improvements to throttling / back-off
   - additional env variables to enable more control
   - more conservative defaults to prioritize success over raw speed
   - less logging by default, verbose enabled by env var

 - v1.0
   - Initial public release

## Enterprise and Support Options
This extension is free for personal and commercial use under the terms in LICENSE. For enterprise features, including:

- Source code access (under NDA)
- Security audits and certifications
- Custom modifications or integrations
- Ongoing support SLAs (e.g., priority bug fixes, updates)


Contact Jojitech LLC at info@jojitech.com
