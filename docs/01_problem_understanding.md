# Phase 1: Understanding the Problems

We read the brief as a mix of everyday features members use and reports teams run in the background. The database needs to respond quickly when someone is waiting on a page or applying for a job. Broader summaries can take longer, as long as they are ready when the teams need them.

## What the teams need

| Problem | Our understanding and who it affects | Workload and queries |
|---|---|---|
| **P1 — Profiles and network** | Members should be able to open a profile and see someone's work history, connections, and shared contacts without waiting around. The delay is most noticeable for members with large networks. | **Customer-facing / real-time** — R01–R04 |
| **P2 — Suggestions and invitations** | Members need useful second-degree connection suggestions and an invitations page that responds quickly. The growth team depends on these features to help members build their networks. | **Customer-facing / real-time** — R05, R10, W02, W03 |
| **P3 — Finding and applying for jobs** | Job seekers need relevant results and recommendations, and an application should be recorded right away. Recruiters and employers also rely on applications being saved correctly. | **Customer-facing / real-time** — R06, R07, R09, W01 |
| **P4 — Recruiter tools** | Recruiters need to see applicants by stage and find suitable candidates. Reviewing a live pipeline or searching for candidates is interactive; clearing old applications can happen as a batch job. | **Mostly customer-facing / real-time; W05 is batch work** — R08, R18, W05 |
| **P5 — Profile views and re-engagement** | Members want to know who has viewed their profile, with private visits counted separately. The engagement team also needs to find members who have never viewed anyone else's profile so it can plan a re-engagement message. | **Mixed:** R11 is customer-facing / real-time; R13 is reporting / analytics |
| **P6 — Talent insights** | The talent-insights team, company page admins, and business leaders need summaries of tenure, hiring time, requested skills, salaries, career moves, and career breaks. These help with planning and do not need to be calculated while a member waits on a page. | **Reporting / analytics** — R12, R14–R17, R25 |
| **P7 — Platform reports and maintenance** | Platform and trust & safety teams need activity and employer reports that keep working as the data grows. Company page admins may use the employer summaries. Expired jobs must also be closed, while email lookup is needed during sign-in. | **Mixed:** R19–R22 and R24 are reporting / analytics; W04 is batch maintenance; R23 is customer-facing / real-time |

## Assumptions we will use

- We will treat the 30 supplied queries as the workload to measure. When we optimize them, their results should stay the same.
- We will treat jobs with `status = 'OPEN'` as available to members, following the query definitions.
- A profile view with no `viewer_id` is a private-mode visit. We will count it without trying to identify the viewer.
- A connection is meant to be a two-way relationship stored once. We will check the member ordering and duplicates in the CSVs before enforcing that rule.
- We expect a member to apply only once to a particular job. We will check the export before adding that constraint.
- The timestamps include an India time offset, so we will use time-zone-aware types for event times.
- We will treat page reads and member actions as interactive work, and full-population reports or maintenance as analytics or batch work.
