\set ON_ERROR_STOP on

BEGIN;

LOCK TABLE
  public.users,
  public.teams,
  public.team_memberships,
  public.sites,
  public.goals,
  public.setup_success_emails,
  public.tracker_script_configuration
IN ACCESS EXCLUSIVE MODE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM migration_old.users old JOIN public.users current USING (email)
  ) THEN
    RAISE EXCEPTION 'user email collision in Plausible merge';
  END IF;

  IF EXISTS (
    SELECT 1 FROM migration_old.teams old JOIN public.teams current USING (identifier)
  ) THEN
    RAISE EXCEPTION 'team identifier collision in Plausible merge';
  END IF;

  IF EXISTS (
    SELECT 1 FROM migration_old.sites old JOIN public.sites current USING (domain)
  ) THEN
    RAISE EXCEPTION 'site domain collision in Plausible merge';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM migration_old.tracker_script_configuration old
    JOIN public.tracker_script_configuration current USING (id)
  ) THEN
    RAISE EXCEPTION 'tracker configuration ID collision in Plausible merge';
  END IF;
END
$$;

CREATE TEMP TABLE migration_user_map ON COMMIT DROP AS
SELECT
  id AS old_id,
  row_number() OVER (ORDER BY id) + (SELECT coalesce(max(id), 0) FROM public.users) AS new_id
FROM migration_old.users;

CREATE TEMP TABLE migration_team_map ON COMMIT DROP AS
SELECT
  id AS old_id,
  row_number() OVER (ORDER BY id) + (SELECT coalesce(max(id), 0) FROM public.teams) AS new_id
FROM migration_old.teams;

CREATE TEMP TABLE migration_team_membership_map ON COMMIT DROP AS
SELECT
  id AS old_id,
  row_number() OVER (ORDER BY id) + (SELECT coalesce(max(id), 0) FROM public.team_memberships) AS new_id
FROM migration_old.team_memberships;

CREATE TEMP TABLE migration_site_map ON COMMIT DROP AS
SELECT
  id AS old_id,
  row_number() OVER (ORDER BY id) + (SELECT coalesce(max(id), 0) FROM public.sites) AS new_id
FROM migration_old.sites;

CREATE TEMP TABLE migration_goal_map ON COMMIT DROP AS
SELECT
  id AS old_id,
  row_number() OVER (ORDER BY id) + (SELECT coalesce(max(id), 0) FROM public.goals) AS new_id
FROM migration_old.goals;

CREATE TEMP TABLE migration_setup_success_map ON COMMIT DROP AS
SELECT
  id AS old_id,
  row_number() OVER (ORDER BY id) + (SELECT coalesce(max(id), 0) FROM public.setup_success_emails) AS new_id
FROM migration_old.setup_success_emails;

INSERT INTO public.users
SELECT (
  jsonb_populate_record(
    NULL::public.users,
    to_jsonb(old) || jsonb_build_object('id', map.new_id)
  )
).*
FROM migration_old.users old
JOIN migration_user_map map ON map.old_id = old.id;

INSERT INTO public.teams
SELECT (
  jsonb_populate_record(
    NULL::public.teams,
    to_jsonb(old) || jsonb_build_object('id', map.new_id)
  )
).*
FROM migration_old.teams old
JOIN migration_team_map map ON map.old_id = old.id;

INSERT INTO public.team_memberships
SELECT (
  jsonb_populate_record(
    NULL::public.team_memberships,
    to_jsonb(old) || jsonb_build_object(
      'id', membership_map.new_id,
      'user_id', user_map.new_id,
      'team_id', team_map.new_id
    )
  )
).*
FROM migration_old.team_memberships old
JOIN migration_team_membership_map membership_map ON membership_map.old_id = old.id
JOIN migration_user_map user_map ON user_map.old_id = old.user_id
JOIN migration_team_map team_map ON team_map.old_id = old.team_id;

INSERT INTO public.sites
SELECT (
  jsonb_populate_record(
    NULL::public.sites,
    to_jsonb(old) || jsonb_build_object(
      'id', site_map.new_id,
      'team_id', team_map.new_id
    )
  )
).*
FROM migration_old.sites old
JOIN migration_site_map site_map ON site_map.old_id = old.id
JOIN migration_team_map team_map ON team_map.old_id = old.team_id;

INSERT INTO public.goals
SELECT (
  jsonb_populate_record(
    NULL::public.goals,
    to_jsonb(old) || jsonb_build_object(
      'id', goal_map.new_id,
      'site_id', site_map.new_id
    )
  )
).*
FROM migration_old.goals old
JOIN migration_goal_map goal_map ON goal_map.old_id = old.id
JOIN migration_site_map site_map ON site_map.old_id = old.site_id;

INSERT INTO public.setup_success_emails
SELECT (
  jsonb_populate_record(
    NULL::public.setup_success_emails,
    to_jsonb(old) || jsonb_build_object(
      'id', setup_map.new_id,
      'site_id', site_map.new_id
    )
  )
).*
FROM migration_old.setup_success_emails old
JOIN migration_setup_success_map setup_map ON setup_map.old_id = old.id
JOIN migration_site_map site_map ON site_map.old_id = old.site_id;

INSERT INTO public.tracker_script_configuration
SELECT (
  jsonb_populate_record(
    NULL::public.tracker_script_configuration,
    to_jsonb(old) || jsonb_build_object('site_id', site_map.new_id)
  )
).*
FROM migration_old.tracker_script_configuration old
JOIN migration_site_map site_map ON site_map.old_id = old.site_id;

SELECT setval(pg_get_serial_sequence('public.users', 'id'), max(id), true) FROM public.users;
SELECT setval(pg_get_serial_sequence('public.teams', 'id'), max(id), true) FROM public.teams;
SELECT setval(pg_get_serial_sequence('public.team_memberships', 'id'), max(id), true) FROM public.team_memberships;
SELECT setval(pg_get_serial_sequence('public.sites', 'id'), max(id), true) FROM public.sites;
SELECT setval(pg_get_serial_sequence('public.goals', 'id'), max(id), true) FROM public.goals;
SELECT setval(pg_get_serial_sequence('public.setup_success_emails', 'id'), max(id), true) FROM public.setup_success_emails;

COMMIT;

SELECT
  old.id AS old_site_id,
  current.id AS new_site_id,
  old.domain
FROM migration_old.sites old
JOIN public.sites current USING (domain)
ORDER BY old.id;
