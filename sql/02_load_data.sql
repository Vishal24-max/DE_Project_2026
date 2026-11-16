-- From the project folder, run this after 01_schema.sql and after unzipping seed_data.zip.
-- The parent tables come first so every reference has a row to point to.
SET search_path TO linkedin;

\copy linkedin.cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.companies FROM 'seed_data/companies.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.skills FROM 'seed_data/skills.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.members FROM 'seed_data/members.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.positions FROM 'seed_data/positions.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.member_skills FROM 'seed_data/member_skills.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.connections FROM 'seed_data/connections.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.invitations FROM 'seed_data/invitations.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.jobs FROM 'seed_data/jobs.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.job_skills FROM 'seed_data/job_skills.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.applications FROM 'seed_data/applications.csv' WITH (FORMAT csv, HEADER true)
\copy linkedin.profile_views FROM 'seed_data/profile_views.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;

-- We checked the load against these counts; they should match after the import.
-- cities 10; members 40000; companies 2000; positions 99940; skills 72;
-- member_skills 212417; connections 219966; invitations 60000; jobs 15000;
-- job_skills 65719; applications 149984; profile_views 199996.
