-- We are starting with the rules the CSV data needs. We will add performance
-- indexes later, so there are no hand-made indexes in this file.
-- Run this once in an empty PostgreSQL 15+ database.
CREATE SCHEMA linkedin;
SET search_path TO linkedin;

-- City names can repeat in different states, so we use the name and state together.
CREATE TABLE cities (
    city_id   integer PRIMARY KEY,
    city_name text NOT NULL,
    state     text NOT NULL,
    CONSTRAINT cities_name_state_unique UNIQUE (city_name, state)
);

CREATE TABLE companies (
    company_id   integer PRIMARY KEY,
    company_name text NOT NULL,
    industry     text NOT NULL,
    company_size text NOT NULL CHECK (company_size IN ('1-10', '11-50', '51-200', '201-1000', '1001-5000', '5001-10000', '10001+')),
    hq_city_id   integer REFERENCES cities(city_id) ON DELETE SET NULL,
    founded_year smallint CHECK (founded_year BETWEEN 1800 AND 2100),
    website      text
);

CREATE TABLE skills (
    skill_id   integer PRIMARY KEY,
    skill_name text NOT NULL UNIQUE
);

CREATE TABLE members (
    member_id    integer PRIMARY KEY,
    first_name   text NOT NULL,
    last_name    text NOT NULL,
    headline     text,
    email        text NOT NULL UNIQUE,
    city_id      integer REFERENCES cities(city_id) ON DELETE SET NULL,
    industry     text NOT NULL,
    is_premium   boolean NOT NULL,
    open_to_work boolean NOT NULL,
    created_at   timestamptz NOT NULL
);

CREATE TABLE positions (
    position_id     integer PRIMARY KEY,
    member_id       integer NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    company_id      integer NOT NULL REFERENCES companies(company_id) ON DELETE RESTRICT,
    title           text NOT NULL,
    employment_type text NOT NULL CHECK (employment_type IN ('FULL_TIME', 'CONTRACT', 'INTERNSHIP')),
    start_date      date NOT NULL,
    end_date        date,
    -- In the export, a blank end date means the member still has this role.
    CONSTRAINT positions_valid_date_range CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Each member-skill pair appears once; endorsements belong to that pair.
CREATE TABLE member_skills (
    member_id   integer NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    skill_id    integer NOT NULL REFERENCES skills(skill_id) ON DELETE CASCADE,
    endorsements integer NOT NULL CHECK (endorsements >= 0),
    PRIMARY KEY (member_id, skill_id)
);

CREATE TABLE connections (
    member_a    integer NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    member_b    integer NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    connected_at timestamptz NOT NULL,
    PRIMARY KEY (member_a, member_b),
    -- We put the smaller ID first so a two-way connection is stored only once.
    CONSTRAINT connections_ordered_pair CHECK (member_a < member_b)
);

CREATE TABLE invitations (
    invitation_id integer PRIMARY KEY,
    sender_id     integer NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    recipient_id  integer NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    note          text,
    sent_at       timestamptz NOT NULL,
    status        text NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'IGNORED', 'WITHDRAWN')),
    responded_at  timestamptz,
    CONSTRAINT invitations_not_self CHECK (sender_id <> recipient_id),
    -- In our data, pending invitations have no response time; answered ones do.
    CONSTRAINT invitations_response_state CHECK ((status = 'PENDING') = (responded_at IS NULL))
);

CREATE TABLE jobs (
    job_id          integer PRIMARY KEY,
    company_id      integer NOT NULL REFERENCES companies(company_id) ON DELETE RESTRICT,
    title           text NOT NULL,
    city_id         integer REFERENCES cities(city_id) ON DELETE RESTRICT,
    workplace_type  text NOT NULL CHECK (workplace_type IN ('ONSITE', 'HYBRID', 'REMOTE')),
    employment_type text NOT NULL CHECK (employment_type IN ('FULL_TIME', 'CONTRACT', 'INTERNSHIP')),
    min_experience  smallint NOT NULL CHECK (min_experience >= 0),
    min_salary_lpa  numeric(6,2) CHECK (min_salary_lpa IS NULL OR min_salary_lpa >= 0),
    max_salary_lpa  numeric(6,2) CHECK (max_salary_lpa IS NULL OR max_salary_lpa >= 0),
    posted_at       timestamptz NOT NULL,
    closes_at       timestamptz NOT NULL,
    status          text NOT NULL CHECK (status IN ('OPEN', 'CLOSED')),
    CONSTRAINT jobs_salary_range CHECK (min_salary_lpa IS NULL OR max_salary_lpa IS NULL OR max_salary_lpa >= min_salary_lpa),
    -- Remote jobs have no city in this export; onsite and hybrid jobs do.
    CONSTRAINT jobs_workplace_city CHECK ((workplace_type = 'REMOTE') = (city_id IS NULL)),
    CONSTRAINT jobs_valid_posting_window CHECK (closes_at >= posted_at)
);

CREATE TABLE job_skills (
    job_id  integer NOT NULL REFERENCES jobs(job_id) ON DELETE CASCADE,
    skill_id integer NOT NULL REFERENCES skills(skill_id) ON DELETE CASCADE,
    PRIMARY KEY (job_id, skill_id)
);

CREATE TABLE applications (
    application_id   integer PRIMARY KEY,
    job_id           integer NOT NULL REFERENCES jobs(job_id) ON DELETE RESTRICT,
    member_id        integer NOT NULL REFERENCES members(member_id) ON DELETE RESTRICT,
    applied_at       timestamptz NOT NULL,
    easy_apply       boolean NOT NULL,
    status           text NOT NULL CHECK (status IN ('APPLIED', 'VIEWED', 'SHORTLISTED', 'INTERVIEW', 'OFFER', 'HIRED', 'REJECTED', 'WITHDRAWN')),
    status_updated_at timestamptz NOT NULL,
    -- A member can apply to a particular job only once.
    CONSTRAINT applications_one_per_job_member UNIQUE (job_id, member_id),
    CONSTRAINT applications_status_time CHECK (status_updated_at >= applied_at)
);

CREATE TABLE profile_views (
    view_id    integer PRIMARY KEY,
    -- A NULL viewer is how private-mode views are represented in the export.
    viewer_id  integer REFERENCES members(member_id) ON DELETE SET NULL,
    viewed_id  integer NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    viewed_at  timestamptz NOT NULL,
    CONSTRAINT profile_views_not_self CHECK (viewer_id IS NULL OR viewer_id <> viewed_id)
);
