-- Phase 4 indexes. Run this after loading the seed data.
SET search_path TO linkedin;

-- R01 and R02 look up a member's positions and show the newest first.
CREATE INDEX positions_member_start_idx
    ON positions (member_id, start_date DESC)
    INCLUDE (company_id, title, employment_type, end_date);
-- R12 looks for current employees by company, so this only stores current roles.
CREATE INDEX positions_current_company_idx
    ON positions (company_id, member_id, start_date)
    WHERE end_date IS NULL;
-- The same member/date order helps the history windows in R17 and R25.

-- The primary key starts with member_a. This index makes lookups by member_b quick too.
CREATE INDEX connections_member_b_idx
    ON connections (member_b, connected_at DESC)
    INCLUDE (member_a);

-- R07 starts from the skills a member has and finds jobs that ask for them.
CREATE INDEX job_skills_skill_job_idx ON job_skills (skill_id, job_id);
-- R18 and R21 use the skill first, then the endorsement count to rank members.
CREATE INDEX member_skills_skill_rank_idx
    ON member_skills (skill_id, endorsements DESC, member_id);

-- R10, W02 and W03 only need pending invitations. Put recipient first, then oldest ID.
CREATE INDEX invitations_pending_recipient_idx
    ON invitations (recipient_id, invitation_id)
    INCLUDE (sender_id, sent_at, note)
    WHERE status = 'PENDING';
-- R24 filters invitations by date and then joins each sender to members.
CREATE INDEX invitations_sent_sender_idx ON invitations (sent_at, sender_id) INCLUDE (status);

-- R11 looks up views of one profile by date. Include viewer_id for the result.
CREATE INDEX profile_views_viewed_time_idx
    ON profile_views (viewed_id, viewed_at DESC)
    INCLUDE (viewer_id);
CREATE INDEX profile_views_viewer_idx ON profile_views (viewer_id) WHERE viewer_id IS NOT NULL;

-- R06, R15 and R16 filter or order jobs by their posting date.
-- R19 counts jobs by employer and status.
CREATE INDEX jobs_company_status_idx ON jobs (company_id, status);
CREATE INDEX jobs_posted_idx ON jobs (posted_at) INCLUDE (job_id, title, company_id, city_id);
-- R07 and R19 join to open jobs by job_id, so this index only stores open jobs.
CREATE INDEX jobs_open_id_idx ON jobs (job_id) WHERE status = 'OPEN';
-- W04 finds open jobs whose closing date has passed.
CREATE INDEX jobs_expired_open_idx ON jobs (closes_at) WHERE status = 'OPEN';

-- R09 finds one member's applications and shows the newest ones first.
CREATE INDEX applications_member_applied_idx
    ON applications (member_id, applied_at DESC)
    INCLUDE (application_id, job_id, status);
-- R14 filters hires by the time their status was updated.
CREATE INDEX applications_hired_updated_idx
    ON applications (status_updated_at, job_id)
    INCLUDE (applied_at) WHERE status = 'HIRED';
-- R19 and R20 filter by application date; R22 returns applications newest first.
CREATE INDEX applications_applied_desc_idx
    ON applications (applied_at DESC)
    INCLUDE (application_id, job_id, member_id, status);
-- W05 only changes applications still in the APPLIED stage.
CREATE INDEX applications_unreviewed_job_date_idx
    ON applications (job_id, applied_at)
    WHERE status = 'APPLIED';

-- R23 searches with lower(email), so the index uses that same expression.
CREATE INDEX members_lower_email_idx ON members (lower(email));

ANALYZE;
