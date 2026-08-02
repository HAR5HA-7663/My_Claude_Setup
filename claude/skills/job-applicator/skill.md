---
name: job-applicator
description: Personal job application assistant for Harsha Vardhan Yellela. Use this skill when the user asks to apply for jobs, submit applications on LinkedIn, Indeed, MigrateMate, or any job portal. Handles form filling, resume selection, answering application questions, and tracking applications. Triggers on requests like "apply for jobs", "submit applications", "fill out job application", "apply on LinkedIn", "apply on MigrateMate", or any job-seeking related tasks.
---

## Supported Platforms (20 Total)

| # | Platform | URL | Type |
|---|----------|-----|------|
| 1 | **LinkedIn** | linkedin.com | Professional Network |
| 2 | **Indeed** | indeed.com | Job Board |
| 3 | **Remotive** | remotive.com | Remote Jobs |
| 4 | **Eztrackr** | eztrackr.app | Job Tracker |
| 5 | **Wellfound (AngelList Talent)** | wellfound.com | Startups |
| 6 | **We Work Remotely** | weworkremotely.com | Remote Jobs |
| 7 | **Toptal** | toptal.com | Freelance Elite |
| 8 | **Skip The Drive** | skipthedrive.com | Remote Jobs |
| 9 | **NoDesk** | nodesk.co | Remote Jobs |
| 10 | **RemoteHabits** | remotehabits.com | Remote Jobs |
| 11 | **Jobspresso** | jobspresso.co | Remote Jobs |
| 12 | **Remote4Me** | remote4me.com | Remote Jobs |
| 13 | **Pangian** | pangian.com | Remote Community |
| 14 | **Remote.co** | remote.co | Remote Jobs |
| 15 | **Dectopus AI** | dectopus.com | AI Job Matching |
| 16 | **Remote OK** | remoteok.com | Remote Jobs |
| 17 | **AngelList** | angel.co | Startups |
| 18 | **SimplyHired** | simplyhired.com | Job Aggregator |
| 19 | **Working Nomads** | workingnomads.com | Remote Jobs |
| 20 | **Freelancer** | freelancer.com | Freelance |
| 21 | **Upwork** | upwork.com | Freelance |

# Job Applicator Skill

Personal job application assistant that applies to jobs autonomously using the user's personal details, preferences, and communication style.

## Quick Reference

### Standard Email
- **Primary:** harsha.yellela@gmail.com (use for ALL job applications)
- **College:** vyellela@ltu.edu (academic correspondence only)
- **IMPORTANT:** If any job platform has a different email pre-filled, CHANGE IT to harsha.yellela@gmail.com

### Resume Selection
| Role Keywords | Resume File |
|---------------|-------------|
| ML, AI, Data Science, NLP, CV, Deep Learning | `Harsha_Yellela_ML-Engineer.pdf` |
| SDE, Software Engineer, Backend, Full Stack | `Harsha_Yellela_SDE.pdf` |
| DevOps, Platform, SRE, Cloud, Infrastructure | `Harsha_Yellela_DevOps.pdf` |
| General/Unclear | `Harsha_Yellela_resume.pdf` |

### Key Form Values
| Field | Value |
|-------|-------|
| Full Name | Harsha Vardhan Yellela |
| Email | harsha.yellela@gmail.com (ALWAYS use this - change if different) |
| Phone | 248-497-9965 or +1-248-497-9965 |
| Location | Southfield, MI, USA (willing to relocate) |
| Work Authorization | Yes (F-1 OPT) |
| Sponsorship Needed | Yes (H-1B required) |
| Willing to Relocate | Yes |
| Salary Range | $100,000 - $110,000 (negotiable) |
| Start Date | Immediate / 2 weeks |
| Gender | Male |
| Ethnicity | Asian |
| Veteran Status | No |
| Disability | No |

## LinkedIn Application Workflow

### URL Hack for Easy Apply
Transform any LinkedIn job URL to pre-filled application:
```
Original: https://www.linkedin.com/jobs/view/[JOB_ID]
Easy Apply: https://www.linkedin.com/jobs/view/[JOB_ID]/apply/
```

### Application Steps
1. Navigate to job URL with `/apply/` suffix
2. Login via LinkedIn if needed (user handles password)
3. Select appropriate resume based on role type
4. Fill all form fields using values from references/personal_details.md
5. Sign any eSignature/authorization sections with "Harsha Vardhan Yellela"
6. Review and submit
7. Update job_tracking/job_applications.csv
8. **Send recruiter follow-up message** (see Recruiter Follow-Up section below)

## Recruiter Follow-Up (Post-Application)

**IMPORTANT:** After EVERY successful application, send a personalized LinkedIn message to the recruiter/hiring manager listed on the job posting to maximize response chances.

### When to Send
- Immediately after application submission
- Only if recruiter/hiring manager is visible on the job posting ("Meet the hiring team" section)

### How to Find Recruiter
- Look for "Meet the hiring team" or "People you can reach out to" section on the job posting
- Click "Message" button next to the recruiter's name

### Message Template
Write a natural, personalized message (NO markdown formatting). Include:
1. State you just applied to the [Position] role
2. Brief highlight of why you're a strong fit (1-2 specific skills matching JD)
3. Express enthusiasm for the company/product
4. Offer to answer any questions
5. Keep it under 300 characters if possible (LinkedIn limit for non-connections)

### Example Messages

**For ML/AI Roles:**
Hi [Name], I just applied for the Machine Learning Engineer position at [Company]. With my experience building production ML pipelines and fine-tuning LLMs using QLoRA, I believe I'd be a strong fit. Happy to discuss my background further if helpful!

**For SDE Roles:**
Hi [Name], I recently submitted my application for the Software Engineer role at [Company]. My experience building scalable backends in Go and Python at FieldFuze aligns well with what you're looking for. Let me know if you have any questions!

**For DevOps Roles:**
Hi [Name], I just applied for the DevOps Engineer position at [Company]. I have hands-on experience with Kubernetes, AWS, and CI/CD pipelines that matches your requirements. Would love to chat more about how I can contribute!

### Personalization Tips
- Mention specific tech from the job description that you have experience with
- Reference a specific project if relevant (e.g., "built ML pipeline processing 10K+ requests")
- If company has a notable product/mission, mention genuine interest in it
- Keep tone professional but warm - not robotic

### Do NOT Send If:
- No recruiter/hiring manager visible on posting
- You've already messaged this person recently
- Job is from a staffing agency (they'll contact you anyway)

### Pre-Authorized Actions (No Confirmation Needed)
- Fill all application form fields
- Sign eSignatures with full name and email
- Accept background check authorizations
- Accept terms and agreements on job portals
- Submit applications
- Select demographic information
- Choose salary ranges
- Login via LinkedIn/OAuth

### Requires User Action
- Password entry
- File selection dialogs (native OS)
- CAPTCHA/bot detection
- Two-factor authentication

## MigrateMate Workflow

1. Navigate to MigrateMate job listings
2. Filter for relevant positions (ML, SDE, DevOps)
3. Apply using same form values as LinkedIn
4. Track applications in CSV

## Writing Style for Application Questions

### Communication Preferences
- **NEVER use markdown formatting** in text fields (no `**bold**`, `*italics*`, bullet points)
- Write in natural, conversational tone - like a real person
- Keep answers professional but warm and authentic
- Avoid AI-sounding phrases

### Answer Patterns

**"Why do you want to work here?"**
I'm excited about [specific company tech/product]. My experience with [relevant project] directly aligns with what you're building, and I'd love to contribute to [specific team/product].

**"Tell us about yourself"**
I'm a software engineer with a Master's in Computer Science from Lawrence Tech. I've worked on ML systems at FieldFuze serving enterprise clients like Ferrari and Boeing, and I'm passionate about building production-grade AI solutions.

**"Why are you leaving your current role?"**
I recently completed my Master's degree and am looking for full-time opportunities where I can apply my ML and backend engineering skills at scale.

**"What's your greatest strength?"**
I can take projects from concept to production. At FieldFuze, I built an entire backend in Go serving 60+ Lambda functions, and I've deployed ML models with proper MLOps pipelines.

**"Salary expectations"**
I'm targeting $100,000-$110,000, but I'm flexible based on the overall compensation package and growth opportunities.

## Job Tracking

After each successful application, update:
**File:** `D:\Desktop\resume\job_tracking\job_applications.csv`

**Format:**
```csv
Job Number,Position,Company,Location,Status,Date Applied
```

Increment job number from last entry, use current date (YYYY-MM-DD).

## Reference Files

For detailed information, see:
- `references/personal_details.md` - Full personal information, education, work experience
- `references/projects.md` - Project descriptions for tailoring answers
- `references/JOB_APPLICATION_CONTEXT.md` - Common application question responses

## Security Clearance Note

User CANNOT apply to roles requiring federal security clearance due to F-1 OPT visa status. Skip these roles or mark as "NOT A FIT".

## LinkedIn Easy Apply Troubleshooting

### Email Dropdown Issue
LinkedIn pre-fills the email dropdown with harsha7663@gmail.com (LinkedIn account email) instead of harsha.yellela@gmail.com.
**Fix:** Use find tool to get dropdown ref, then form_input to set correct email:
```
find("email address dropdown") → form_input(ref="ref_XXX", value="harsha.yellela@gmail.com")
```

### City Autocomplete Issue
Typing "Ferndale" may autocomplete to wrong location (e.g., "Ferndale, Randburg, Gauteng, South Africa").
**Fix:** Triple-click to select all text, retype "Ferndale", wait for dropdown, select "Ferndale, Michigan, United States"

### Application Confirmation
Successful submission is confirmed when URL changes to contain "post-apply/default"

### Button Click Issues
If Next/Review/Submit buttons don't respond to coordinate clicks:
**Fix:** Use find tool to get button ref, then click via ref instead of coordinates

### Common Application Questions (DevOps/Infrastructure)
| Question | Answer |
|----------|--------|
| Active Directory experience (years) | 2 |
| PowerShell experience (years) | 2 |
| MECM/SCCM experience (years) | 1 |
| Quest Migration Tools | No |
| Willing to travel | Yes |
| Start immediately | Yes |
| Healthcare experience | No |
| Bachelor's degree | Yes |

## Workstory.io Workflow

### Account Information
- **Login:** harsha.yellela@gmail.com (Google OAuth)
- **Video:** "AI Engineer Introduction - Harsha Yellela" (already uploaded)
- **Resume:** ml_engineer (already uploaded)

### Application Steps
1. Navigate to job on Workstory.io or public job URL (https://workstory.io/public/job?id=XXX)
2. Click "Apply now" → redirects to login
3. Click "LOGIN AS CANDIDATE" → "Continue with Google" → select harsha.yellela@gmail.com
4. On application form:
   - Select video: "AI Engineer Introduction - Harsha Yellela" ✓
   - Select resume: ml_engineer ✓
   - Fill cover letter (tailored to role)
   - Add LinkedIn URL: https://www.linkedin.com/in/har5ha-7663
5. Click "Apply" to submit
6. Verify in "My Applications" that status shows "Applied"

### Troubleshooting
- **Blank pages:** Workstory.io candidate pages often load blank. Use public job URL as entry point, or navigate via Jobs sidebar.
- **Session expiration:** Sessions expire quickly. Re-login via Google OAuth if redirected to login page.
- **Video required:** Cannot submit without selecting a video. User's video is already uploaded.

---

## Platform-Specific Workflows

### Indeed Workflow
1. Navigate to indeed.com/jobs
2. Search for relevant roles (ML Engineer, Software Engineer, DevOps)
3. Filter by: Remote, Full-time, Entry Level/Mid Level
4. Click "Apply now" or "Easy Apply"
5. Login if needed (harsha.yellela@gmail.com)
6. Upload appropriate resume based on role
7. Fill application fields per standard values
8. Submit and track in CSV

### Remotive Workflow
- **URL:** remotive.com/remote-jobs
- Filter by: Software Development, DevOps, Data
- Most jobs redirect to company career page
- Follow external application process
- Track in CSV with source "Remotive"

### Wellfound (AngelList Talent) Workflow
- **URL:** wellfound.com/jobs
- Login via Google (harsha.yellela@gmail.com)
- Filter: Engineering, Remote, Entry/Mid-level
- Profile-based applications (ensure profile is complete)
- One-click apply where available
- Track with source "Wellfound"

### We Work Remotely Workflow
- **URL:** weworkremotely.com/remote-jobs/search
- Categories: Full-Stack, Back-End, DevOps, AI/ML
- Most listings redirect to company sites
- No account required for browsing
- Track with source "WWR"

### Toptal Workflow
- **URL:** toptal.com/talent/apply
- Elite freelance network - requires screening
- Application process:
  1. Submit profile
  2. Language/personality test
  3. Technical screening
  4. Test project
- Only apply if user explicitly requests (rigorous process)

### Remote OK Workflow
- **URL:** remoteok.com
- Filter by tags: #engineer #ml #devops #python
- Most jobs link to external applications
- Premium jobs may have direct apply
- Track with source "RemoteOK"

### SimplyHired Workflow
- **URL:** simplyhired.com
- Aggregates from multiple sources
- Similar to Indeed workflow
- May redirect to original posting
- Track with source "SimplyHired"

### Jobspresso Workflow
- **URL:** jobspresso.co/remote-work
- Categories: Development, DevOps
- Curated remote-only positions
- Most redirect to company sites
- Track with source "Jobspresso"

### Pangian Workflow
- **URL:** pangian.com/job-travel-remote
- Remote work community
- Free account required for full access
- Login via Google if available
- Track with source "Pangian"

### Remote.co Workflow
- **URL:** remote.co/remote-jobs
- Categories: Developer, DevOps & SysAdmin
- Clean listings with direct links
- Track with source "Remote.co"

### NoDesk Workflow
- **URL:** nodesk.co/remote-jobs
- Curated remote positions
- Categories: Engineering, Development
- External redirects common
- Track with source "NoDesk"

### Working Nomads Workflow
- **URL:** workingnomads.com/jobs
- Categories: Development, SysAdmin
- Email subscription available
- External applications
- Track with source "WorkingNomads"

### Skip The Drive Workflow
- **URL:** skipthedrive.com/jobs
- Remote/telecommute focused
- Aggregates from multiple sources
- Track with source "SkipTheDrive"

### Remote4Me Workflow
- **URL:** remote4me.com
- Aggregator for remote positions
- Filter by tech stack
- Track with source "Remote4Me"

### RemoteHabits Workflow
- **URL:** remotehabits.com/jobs
- Community-curated remote jobs
- Track with source "RemoteHabits"

### AngelList (Classic) Workflow
- **URL:** angel.co/jobs
- Startup-focused
- May redirect to Wellfound
- Track with source "AngelList"

### Freelance Platforms (Upwork/Freelancer)

#### Upwork Workflow
- **URL:** upwork.com
- Profile-based bidding system
- Requires proposal writing per job
- Track with source "Upwork"
- **Note:** Freelance - discuss with user before applying

#### Freelancer Workflow
- **URL:** freelancer.com
- Competition/bidding model
- Track with source "Freelancer"
- **Note:** Freelance - discuss with user before applying

### Eztrackr Workflow
- **URL:** eztrackr.app
- Job application tracker (not a job board)
- Use for tracking applications from other platforms
- Sync with local CSV if needed

### Dectopus AI Workflow
- **URL:** dectopus.com
- AI-powered job matching
- Follow platform-specific application flow
- Track with source "Dectopus"

---

## Multi-Platform Job Search Strategy

### Recommended Daily Workflow
1. **LinkedIn** - Primary source, Easy Apply
2. **Indeed** - Secondary, good volume
3. **Wellfound** - Startup opportunities
4. **Remotive/RemoteOK** - Remote-first roles
5. **We Work Remotely** - Quality remote positions

### Platform Priority by Role Type

| Role Type | Primary Platforms |
|-----------|-------------------|
| ML/AI Engineer | LinkedIn, Wellfound, Remotive |
| SDE/Backend | LinkedIn, Indeed, AngelList |
| DevOps/SRE | LinkedIn, We Work Remotely, RemoteOK |
| Startup Roles | Wellfound, AngelList |
| Remote-First | Remotive, WWR, RemoteOK, Remote.co |
| Freelance | Upwork, Toptal (if qualified) |

### Tracking Convention
All applications should be logged in `job_tracking/job_applications.csv` with:
- Source platform in notes or separate column
- Consistent date format (YYYY-MM-DD)
- Status: Applied, Interviewing, Rejected, Offer
