# Falco Issue Triage Report

> **Instructions:** Replace all `{{PLACEHOLDER}}` values with actual data. Remove unused sections. Expand `{{#EACH}}` blocks for each item.

---

> **Generated:** {{DATE}} | **Mode:** {{MODE}} | **Scope:** {{SCOPE}} | **Era:** {{ERA}}

## Table of Contents

{{TOC}}

---

## Executive Summary

| Metric | Count |
|--------|-------|
| Repositories scanned | {{REPO_COUNT}} |
| Open issues analyzed | {{TOTAL_ISSUES}} |
| Open PRs analyzed | {{TOTAL_PRS}} |
| Actionable items | {{ACTIONABLE_COUNT}} |
| Duplicates identified | {{DUPLICATE_COUNT}} |
| Issues already addressed | {{ADDRESSED_COUNT}} |
| Issues needing information | {{NEEDS_INFO_COUNT}} |
| Misunderstandings / doc gaps | {{MISUNDERSTANDING_COUNT}} |

### Key Findings

{{KEY_FINDINGS_BULLETS}}

---

## Categorization Overview

### By Kind

| Kind | Count | Issues |
|------|-------|--------|
{{#EACH KIND}}
| `{{KIND_LABEL}}` | {{COUNT}} | {{ISSUE_REFS}} |
{{/EACH}}
| *Unclassified* | {{UNCLASSIFIED_COUNT}} | {{UNCLASSIFIED_REFS}} |

### By Judged Priority

| Priority | Count | Issues |
|----------|-------|--------|
| Critical | {{CRITICAL_COUNT}} | {{CRITICAL_REFS}} |
| High | {{HIGH_COUNT}} | {{HIGH_REFS}} |
| Medium | {{MEDIUM_COUNT}} | {{MEDIUM_REFS}} |
| Low | {{LOW_COUNT}} | {{LOW_REFS}} |
| *Not assessed* | {{UNASSESSED_COUNT}} | {{UNASSESSED_REFS}} |

### By Repository

| Repository | Open Issues | Open PRs | Needs Triage | Stale |
|------------|-------------|----------|--------------|-------|
{{#EACH REPO}}
| [{{REPO_NAME}}](https://github.com/falcosecurity/{{REPO_NAME}}) | {{ISSUES}} | {{PRS}} | {{NEEDS_TRIAGE}} | {{STALE}} |
{{/EACH}}
| **Total** | **{{TOTAL_ISSUES}}** | **{{TOTAL_PRS}}** | **{{TOTAL_NEEDS_TRIAGE}}** | **{{TOTAL_STALE}}** |

### By Status

| Status | Count | Issues |
|--------|-------|--------|
| Needs triage | {{NEEDS_TRIAGE_COUNT}} | {{NEEDS_TRIAGE_REFS}} |
| Acknowledged | {{ACKNOWLEDGED_COUNT}} | {{ACKNOWLEDGED_REFS}} |
| In progress | {{IN_PROGRESS_COUNT}} | {{IN_PROGRESS_REFS}} |
| Blocked | {{BLOCKED_COUNT}} | {{BLOCKED_REFS}} |
| Stale | {{STALE_COUNT}} | {{STALE_REFS}} |
| Misunderstanding | {{MISUNDERSTANDING_STATUS_COUNT}} | {{MISUNDERSTANDING_STATUS_REFS}} |
| Doc gap | {{DOC_GAP_COUNT}} | {{DOC_GAP_REFS}} |
| Already addressed | {{ADDRESSED_STATUS_COUNT}} | {{ADDRESSED_STATUS_REFS}} |
| Duplicate | {{DUPLICATE_STATUS_COUNT}} | {{DUPLICATE_STATUS_REFS}} |

---

## Issue Groups

### Group {{GROUP_NUMBER}}: {{GROUP_NAME}}

**Type:** {{GROUP_TYPE}} | **Theme:** {{GROUP_THEME}} | **Priority:** {{GROUP_PRIORITY}}

| # | Repository | Title | Kind | Priority | Status | Age |
|---|------------|-------|------|----------|--------|-----|
{{#EACH ISSUE_IN_GROUP}}
| [#{{NUMBER}}]({{URL}}) | `{{REPO}}` | {{TITLE}} | `{{KIND}}` | {{PRIORITY}} | {{STATUS}} | {{AGE}} |
{{/EACH}}

**Analysis:**

{{GROUP_ANALYSIS}}

**Knowledge base context:**

{{GROUP_KB_CONTEXT}}

**Proposed action:**

{{GROUP_PROPOSED_ACTION}}

**Suggested commands:**

```bash
{{GROUP_COMMANDS}}
```

---

*Repeat the "Group" section for each identified group.*

---

## Individual Issue Analysis

> This section contains detailed analysis for issues that received a deep dive. Issues analyzed by quick scan only appear in the groups above with metadata-only assessment.

### [{{REPO}}#{{NUMBER}}]({{URL}}): {{TITLE}}

| Property | Value |
|----------|-------|
| Kind | `{{KIND}}` |
| Era | {{ERA}} |
| Priority | {{PRIORITY}} |
| Status | {{STATUS}} |
| Age | {{AGE}} (created {{CREATED_AT}}) |
| Last updated | {{UPDATED_AT}} |
| Author | @{{AUTHOR}} |
| Assignees | {{ASSIGNEES}} |
| Labels | {{LABELS}} |
| Comments | {{COMMENT_COUNT}} |

**Summary:**

{{ISSUE_SUMMARY}}

**Knowledge base context:**

{{KB_CONTEXT}}

**Status assessment:**

- {{HAS_RELATED_PR}} Has related PR: {{RELATED_PR_DETAILS}}
- {{ADDRESSED_IN_DEV}} Addressed in development branch: {{DEV_BRANCH_DETAILS}}
- {{ACKNOWLEDGED_BY_MAINTAINER}} Acknowledged by maintainer: {{ACKNOWLEDGMENT_DETAILS}}
- {{HAS_CONSENSUS}} Consensus on approach: {{CONSENSUS_DETAILS}}
- {{IS_MISUNDERSTANDING}} Is misunderstanding / doc gap: {{MISUNDERSTANDING_DETAILS}}

**Recommended action:**

{{RECOMMENDED_ACTION}}

**Suggested commands:**

```bash
{{ISSUE_COMMANDS}}
```

---

*Repeat the "Individual Issue Analysis" section for each deep-dived issue.*

---

## PR Analysis

### Stale PRs (> 30 days since last update)

| # | Repository | Title | Author | Last Updated | Days Stale | Reviewers | Recommendation |
|---|------------|-------|--------|--------------|------------|-----------|----------------|
{{#EACH STALE_PR}}
| [#{{NUMBER}}]({{URL}}) | `{{REPO}}` | {{TITLE}} | @{{AUTHOR}} | {{UPDATED_AT}} | {{DAYS_STALE}} | {{REVIEWERS}} | {{RECOMMENDATION}} |
{{/EACH}}

### PRs Needing Review

| # | Repository | Title | Author | Created | Linked Issue | Review Status |
|---|------------|-------|--------|---------|--------------|---------------|
{{#EACH NEEDS_REVIEW_PR}}
| [#{{NUMBER}}]({{URL}}) | `{{REPO}}` | {{TITLE}} | @{{AUTHOR}} | {{CREATED_AT}} | {{LINKED_ISSUE}} | {{REVIEW_STATUS}} |
{{/EACH}}

### Abandoned PRs (> 90 days, no response)

| # | Repository | Title | Author | Last Updated | Recommendation |
|---|------------|-------|--------|--------------|----------------|
{{#EACH ABANDONED_PR}}
| [#{{NUMBER}}]({{URL}}) | `{{REPO}}` | {{TITLE}} | @{{AUTHOR}} | {{UPDATED_AT}} | {{RECOMMENDATION}} |
{{/EACH}}

### Draft PRs

| # | Repository | Title | Author | Created | Last Updated | Notes |
|---|------------|-------|--------|---------|--------------|-------|
{{#EACH DRAFT_PR}}
| [#{{NUMBER}}]({{URL}}) | `{{REPO}}` | {{TITLE}} | @{{AUTHOR}} | {{CREATED_AT}} | {{UPDATED_AT}} | {{NOTES}} |
{{/EACH}}

---

## Duplicates and Related Issues

| Primary Issue | Duplicates | Relationship | Suggested Action |
|--------------|------------|--------------|------------------|
{{#EACH DUPLICATE_GROUP}}
| [{{PRIMARY_REPO}}#{{PRIMARY_NUMBER}}]({{PRIMARY_URL}}) | {{DUPLICATE_REFS}} | {{RELATIONSHIP}} | {{ACTION}} |
{{/EACH}}

---

## Methodology

| Property | Value |
|----------|-------|
| Analysis mode | {{MODE}} |
| Knowledge base era | {{ERA}} |
| Date | {{DATE}} |
| Repositories scanned | {{REPO_LIST}} |
| Total issues analyzed | {{TOTAL_ISSUES}} |
| Total PRs analyzed | {{TOTAL_PRS}} |
| Deep dives performed | {{DEEP_DIVE_COUNT}} |
| Core API calls used | {{CORE_API_USED}} |
| Search API calls used | {{SEARCH_API_USED}} |
| Core API remaining | {{CORE_API_REMAINING}} |
