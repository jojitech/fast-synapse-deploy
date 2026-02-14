<table>
  <tr>
    <td><img src="icon.png" width="48" alt="icon"></td>
    <td><h1>Fast Synapse Deploy</h1></td>
  </tr>
</table>

## Overview
This action will deploy Azure Synapse artifacts, fast! 
It is designed to be a drop-in replacement for the aging *Microsoft Synapse deployment task*, 
with a focus on speed, reliability, and modern features.

### Major Features
 - **Zero Deployment (v3+):** Skips the entire deployment when nothing has changed (via template hash check).
 - **Selective Deployment (v3+):** Deploys only new or modified artifacts—skips unchanged artifacts entirely.
 - **Adaptive Speed Throttling (v2+):** Automatically adjusts request rates, with options for `safe`, `fast`, or `yolo` speeds.
 - **Latest Auth Support:** Azure authentication managed outside of the task to always be up to date including **Federated Credentials (OIDC)**.
 - **Proxy Support**:  HTTP_PROXY, HTTPS_PROXY, and NO_PROXY environment variables.
 - **Large Template Support**: Can be combined with `validate` from [Microsoft task](https://marketplace.visualstudio.com/items?itemName=AzureSynapseWorkspace.synapsecicd-deploy) to overcome [20 MB size issue](https://learn.microsoft.com/en-us/azure/synapse-analytics/cicd/continuous-integration-delivery#1-publish-failed-workspace-arm-file-is-more-than-20-mb).

## Comparison to *Microsoft Synapse deployment task*

In internal testing, Fast Synapse Deploy has shown significant speed improvements over the Microsoft Synapse deployment task, especially for larger deployments.

| Deployment Method | Time to Deploy<br>689 Artifacts | Speedup |
|:------------------|:-------------------------------:|:-------:|
| Microsoft Synapse deployment task | 22m28s | — |
| Fast Synapse Deploy: Full Deployment | 01m17s | **17x faster** 🔥 |
| Fast Synapse Deploy: Selective Deployment | 00m50s | **27x faster** 🚀 |
| Fast Synapse Deploy: Zero Deployment ^1^ | 00m02s | **674x faster** 🤯 |

> [1] To be clear, Zero Deployment detects no changes and skips the deployment entirely.

## Zero Deployment / Hash Check (v3+)
> ⚠️ **Requires task version 3 or later.**

Zero deployment **skips the entire deployment** when nothing has changed. A SHA256 hash of your resolved template is stored in workspace tags and compared on subsequent runs.

### Example Output (No Changes)

```
===========================================================================================
DEPLOYMENT HASH CHECK
===========================================================================================
  Current template hash:  A1B2C3D4E5F6789...
  Stored deployment hash: A1B2C3D4E5F6789...

  [OK] HASHES MATCH - Workspace is already up to date!
===========================================================================================

  ZERO DEPLOYMENT - No changes detected
  Completed in 1.3 seconds
```

### When Deployment Runs

| Scenario | Deploys? |
|----------|----------|
| First deployment | ✅ Yes |
| Template changed | ✅ Yes |
| Parameters changed | ✅ Yes |
| Nothing changed | ❌ Skipped |

---

## Selective Deployment (v3+)

> ⚠️ **Requires task version 3 or later.**

Selective deployment compares your template against the workspace and **deploys only what changed**. Unchanged artifacts are skipped.

Dry run outputs the same analysis but exits without making any changes.

### Example Output

```
=== Selective Deployment Analysis ===
Analysis completed in 45.2 seconds

  NEW artifacts:        12  (will deploy)
  CASCADED artifacts:   28  (will deploy, parent is NEW)
  MODIFIED artifacts:    3  (will deploy)
  UNCHANGED artifacts: 2448  (will SKIP)

Deploying 43 artifacts instead of 2491
Reduction: 98%
```

---

## Throttle Configuration (v2+)

> ⚠️ **Requires task version 2 or later.**

### TL;DR: Leave the Defaults...

**For most users, no configuration is needed.** FastSynapseDeploy automatically:
- Adjusts request rates based on your deployment size
- Backs off and retries when rate limits are hit
- Recovers gracefully from 429 errors

Just run the task and let it handle throttling for you.

### ... Unless you have the Need for Speed

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


If a 429 error occurs, the following happens automatically:
1. Pauses all requests for the cooldown period
2. Reduces concurrency by 25%
3. Tightens RPM limits
4. Retries the failed request

This means **even if you start too aggressive, the tool will adapt**.

> **Tip:** A TooManyRequests (429) event means your deployment had to pause and resume — adding time to your overall deployment. **Ideal deployments have zero 429 events.** If you consistently see rate limit events, consider using `SYNAPSE_DEPLOYMENT_SPEED=safe` or lowering `SYNAPSE_MAX_CONCURRENT_REQUESTS` to avoid the delays caused by cooldown periods.

## Combine with the Microsoft 'Validate' Action
This action can work in tandem with the Microsoft `validate` action, which is required to address a [known issue](https://learn.microsoft.com/en-us/azure/synapse-analytics/cicd/continuous-integration-delivery#1-publish-failed-workspace-arm-file-is-more-than-20-mb) with file size limit during publish. High level, you would first use `validate` to generate the required templates, then use this action to quickly deploy from those templates. 

## Pre-requisites
Requires [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/overview) installed on the agents.

## Not Supported 
 - Deploying ManagedPrivateEndpoints.
 - Deploying *directly* from branch other than `publish`. 
   - However, can be combined with `validate` task (see note below) to achieve same result.

## Star Me
Please consider [leaving a star](https://github.com/marketplace/actions/fast-synapse-deploy) if your workspace was deployed faster!
Also [leave a comment](https://github.com/ShawnMcGough/fast-synapse-deploy/discussions/categories/general). I love to hear how it is helping with deployments!

## Release Notes

### v3
- **Selective Deployment**: Deploy only NEW/MODIFIED artifacts, skip unchanged
- **Zero Deployment**: Skip entire deployment when template hash matches (via `SYNAPSE_ENABLE_HASH_CHECK`)
- **Dry-Run Mode**: Preview changes without deploying (`--selective --dry-run`)
- Dependency cascade optimization: skip content fetch for artifacts whose parent is NEW
- Improved analysis phase with higher RPM for GET requests
- Type-specific JSON normalization for accurate change detection

### v2
- Major improvements to throttling / back-off
- Additional env variables to enable more control (`SYNAPSE_DEPLOYMENT_SPEED`, `SYNAPSE_MAX_CONCURRENT_REQUESTS`, etc.)
- More conservative defaults to prioritize success over raw speed
- Less logging by default, verbose enabled by env var

### v1
   - Initial public release

## Enterprise and Support Options
This extension is free for personal and commercial use under the terms in LICENSE. For enterprise features, including:

- Source code access (under NDA)
- Security audits and certifications
- Custom modifications or integrations
- Ongoing support SLAs (e.g., priority bug fixes, updates)


Contact Jojitech LLC at info@jojitech.com
