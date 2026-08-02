---
name: job-ranker
description: |
  Scrape jobs from a company careers page and rank them by fit for the user. Use when user provides a company careers URL and wants jobs analyzed and ranked. Outputs a CSV with jobs ranked from TOP PICK (best fit) to STRETCH (possible but harder). Filters to US-based roles only. Reads user's personal_details.md for background matching.
---

# Job Ranker Skill

Scrape jobs from a company careers page, filter to US roles, and rank by fit.

## Workflow

1. **Navigate** to the provided careers URL
2. **Extract** all job listings (title, location, URL, requirements if visible)
3. **Filter** to US-based roles only (Remote US, or US cities/states)
4. **Read** user's background from `references/personal_details.md`
5. **Rank** each job using the matching criteria below
6. **Output** CSV file: `ranked_jobs/{company}_jobs_ranked.csv`

## CSV Output Format

```csv
Rank,Job Title,Location,Experience Required,Fit Category,Match Score,Key Matches,Gaps,Job URL
1,ML Engineer,Remote US,3-5 years,TOP PICK,85%,"Python, PyTorch, LLMs",None,https://...
```

## Fit Categories

| Category | Match Score | Meaning |
|----------|-------------|---------|
| **TOP PICK** | 80-100% | Strong match, high confidence |
| **HIGH** | 60-79% | Good match, worth applying |
| **STRETCH** | 40-59% | Some gaps but possible |
| **SKIP** | <40% | Poor fit, don't apply |

## Matching Criteria

### User's Core Competencies (from personal_details.md)
- **ML/AI**: LLM fine-tuning, deep learning, NLP, computer vision, MLOps
- **Backend**: Python (FastAPI), Go, Node.js, microservices
- **DevOps**: Kubernetes, AWS, Docker, CI/CD, Terraform
- **Experience Level**: ~2-3 years (MS CS Dec 2025)
- **Visa**: F-1 OPT, needs H-1B sponsorship

### Auto-SKIP Rules (Do NOT include in CSV)
- Requires security clearance
- Requires 10+ years experience
- Staff/Principal/Director level
- Splunk/SIEM/Salesforce/SAP/Oracle ERP specialist roles
- iOS/Swift only roles
- Mainframe/COBOL

### Scoring Heuristics
- +20% if role matches primary skills (ML, Python, Go, AWS)
- +15% if experience requirement is 2-5 years
- +10% if remote or preferred location (MI, CA, NY, TX, WA)
- -15% if requires 5-7 years experience
- -25% if requires 7+ years experience
- -10% for each major required skill not in user's background

## Execution Notes

- Use browser automation (chrome tools) to navigate and scrape
- If careers page has filters, apply: Location=United States, remote
- If pagination exists, scrape all pages
- Extract job details from listing or click into each job if needed
- Save CSV to `ranked_jobs/` directory
- Report summary: total jobs found, jobs after filtering, breakdown by category
