-- Capsicum full Supabase/PostgreSQL schema snapshot v1.0.0.
-- This is a server snapshot, not the SQLite client schema or a forward migration.
-- Re-running this file is safe for the v1.0.0 baseline. Evolve deployed databases
-- with ordered files under db-schema/migrations/; do not edit an applied migration.
--
-- Every table's id is a server-only index key and must never be synced to clients.
-- uuid is the cross-device identity. Relationships use *_uuid columns and are
-- intentionally not declared as REFERENCES constraints, per db-design-choices.md.
-- Application sync must push a resident and its consent before its encounters.
--
-- No real resident data should be loaded until the v1.1 pilot decisions,
-- clinician review, and privacy/operational acceptance gates are complete.

BEGIN;

DO $$ BEGIN
  CREATE TYPE public.barangay_role AS ENUM ('administrator', 'moderator', 'contributor');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.consent_decision AS ENUM ('granted', 'refused', 'withdrawn');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.consent_template_state AS ENUM ('draft', 'approved', 'retired');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.clinical_rule_state AS ENUM ('draft', 'approved', 'retired');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.community_area_type AS ENUM ('purok', 'sitio');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.hazard_category AS ENUM (
    'unsafe_water',
    'poor_sanitation',
    'garbage',
    'mosquito_breeding',
    'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.review_state AS ENUM (
    'pending',
    'reviewed',
    'follow_up_requested',
    'referred',
    'action_recommended',
    'closed'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.follow_up_kind AS ENUM ('follow_up', 'referral');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.follow_up_state AS ENUM (
    'pending',
    'acknowledged',
    'completed',
    'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.content_category AS ENUM (
    'health_education',
    'public_advisory',
    'facility_information'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.content_state AS ENUM ('draft', 'approved', 'published', 'retired');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- uuid is the Supabase auth user id for signed-in accounts. The public account
-- profile is created by a trigger; membership and system-admin grants are managed
-- by a trusted server operation, never from user-editable auth metadata.
CREATE TABLE IF NOT EXISTS public.account (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  email           text,
  display_name    text,
  is_active       boolean NOT NULL DEFAULT true,
  is_system_admin boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);

CREATE TABLE IF NOT EXISTS public.barangay (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  municipality    text NOT NULL,
  province        text NOT NULL,
  psgc_code       text,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);

CREATE TABLE IF NOT EXISTS public.community_area (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  barangay_uuid   uuid NOT NULL,
  area_type       public.community_area_type NOT NULL,
  name            text NOT NULL,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);

CREATE TABLE IF NOT EXISTS public.account_barangay_role (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  account_uuid    uuid NOT NULL,
  barangay_uuid   uuid NOT NULL,
  role_code       public.barangay_role NOT NULL,
  assigned_by_uuid uuid NOT NULL,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);

-- resident_code is an opaque pilot identifier, not a name, phone number, or
-- government identifier. Confirm its issuance and duplicate-resolution workflow
-- with the RHU before real data is collected.
CREATE TABLE IF NOT EXISTS public.resident (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  barangay_uuid   uuid NOT NULL,
  resident_code   text NOT NULL,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);

CREATE TABLE IF NOT EXISTS public.consent_template (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  version_code    text NOT NULL,
  language_code   text NOT NULL,
  consent_text    text NOT NULL,
  state           public.consent_template_state NOT NULL DEFAULT 'draft',
  approved_by_uuid uuid,
  approved_at     timestamptz,
  effective_at    timestamptz,
  expires_at      timestamptz,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz,
  CONSTRAINT consent_template_version_language_uq UNIQUE (version_code, language_code),
  CONSTRAINT consent_template_effective_range_ck
    CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at)
);

-- Consent decisions are append-only. A later refused/withdrawn decision prevents
-- new encounters. Do not update or physically delete an existing decision.
CREATE TABLE IF NOT EXISTS public.resident_consent (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  resident_uuid       uuid NOT NULL,
  consent_template_uuid uuid NOT NULL,
  purpose_code        text NOT NULL DEFAULT 'health_encounter'
    CHECK (purpose_code = 'health_encounter'),
  decision            public.consent_decision NOT NULL,
  decision_at         timestamptz NOT NULL,
  received_at         timestamptz NOT NULL DEFAULT now(),
  guardian_consent    boolean NOT NULL DEFAULT false,
  created_by_uuid     uuid NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz
);

-- A rule set records the clinician-approved source/version for an encounter
-- workflow. Numeric thresholds are deliberately not invented in this snapshot.
CREATE TABLE IF NOT EXISTS public.clinical_rule_set (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  scope_code      text NOT NULL,
  version_code    text NOT NULL,
  source_title    text NOT NULL,
  source_url      text NOT NULL,
  state           public.clinical_rule_state NOT NULL DEFAULT 'draft',
  approved_by_uuid uuid,
  approved_at     timestamptz,
  effective_at    timestamptz,
  expires_at      timestamptz,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz,
  CONSTRAINT clinical_rule_set_scope_version_uq UNIQUE (scope_code, version_code),
  CONSTRAINT clinical_rule_set_approval_ck
    CHECK (state <> 'approved' OR (approved_by_uuid IS NOT NULL AND approved_at IS NOT NULL)),
  CONSTRAINT clinical_rule_set_effective_range_ck
    CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at)
);

CREATE TABLE IF NOT EXISTS public.encounter (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  resident_uuid       uuid NOT NULL,
  barangay_uuid       uuid NOT NULL,
  encounter_type_code text NOT NULL,
  rule_set_uuid       uuid NOT NULL,
  occurred_at         timestamptz NOT NULL,
  created_by_uuid     uuid NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz
);

-- The pilot form and approved field/unit/rule catalog are still RHU decisions.
-- This table stores typed observations without hard-coding unapproved medical
-- ranges or allowing diagnosis/treatment text.
CREATE TABLE IF NOT EXISTS public.encounter_observation (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  encounter_uuid      uuid NOT NULL,
  field_code          text NOT NULL,
  value_numeric       numeric,
  value_text          text,
  unit_code           text,
  -- Set by the trusted sync service after applying the approved rule set.
  requires_review     boolean NOT NULL DEFAULT false,
  created_by_uuid     uuid NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT encounter_observation_one_value_ck
    CHECK (num_nonnulls(value_numeric, value_text) = 1)
);

CREATE TABLE IF NOT EXISTS public.encounter_review (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  encounter_uuid      uuid NOT NULL,
  state               public.review_state NOT NULL DEFAULT 'pending',
  comment             text,
  reviewer_uuid       uuid,
  reviewed_at         timestamptz,
  created_by_uuid     uuid NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT encounter_review_reviewer_ck
    CHECK ((state = 'pending' AND reviewer_uuid IS NULL AND reviewed_at IS NULL)
        OR (state <> 'pending' AND reviewer_uuid IS NOT NULL AND reviewed_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.health_facility (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  barangay_uuid   uuid,
  name            text NOT NULL,
  facility_type   text NOT NULL,
  public_address  text,
  public_phone    text,
  is_active       boolean NOT NULL DEFAULT true,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);

CREATE TABLE IF NOT EXISTS public.follow_up (
  id                      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                    uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  encounter_uuid          uuid NOT NULL,
  resident_uuid           uuid NOT NULL,
  kind                    public.follow_up_kind NOT NULL,
  due_at                  timestamptz NOT NULL,
  destination_facility_uuid uuid,
  assigned_to_uuid        uuid,
  state                   public.follow_up_state NOT NULL DEFAULT 'pending',
  completed_at            timestamptz,
  created_by_uuid         uuid NOT NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  archived_at             timestamptz,
  CONSTRAINT follow_up_completed_at_ck
    CHECK ((state = 'completed' AND completed_at IS NOT NULL)
        OR (state <> 'completed' AND completed_at IS NULL))
);

CREATE TABLE IF NOT EXISTS public.hazard_report (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  barangay_uuid       uuid NOT NULL,
  community_area_uuid uuid NOT NULL,
  category            public.hazard_category NOT NULL,
  reported_at         timestamptz NOT NULL,
  created_by_uuid     uuid NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz
);

CREATE TABLE IF NOT EXISTS public.hazard_review (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  hazard_report_uuid  uuid NOT NULL,
  state               public.review_state NOT NULL DEFAULT 'pending',
  comment             text,
  reviewer_uuid       uuid,
  reviewed_at         timestamptz,
  created_by_uuid     uuid NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT hazard_review_reviewer_ck
    CHECK ((state = 'pending' AND reviewer_uuid IS NULL AND reviewed_at IS NULL)
        OR (state <> 'pending' AND reviewer_uuid IS NOT NULL AND reviewed_at IS NOT NULL))
);

-- Each language/version is a row. Publication is service-managed for the pilot;
-- the full in-app content-management workflow is explicitly deferred.
CREATE TABLE IF NOT EXISTS public.health_content (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  translation_group_uuid uuid NOT NULL,
  version_number      integer NOT NULL CHECK (version_number > 0),
  category            public.content_category NOT NULL,
  language_code       text NOT NULL,
  title               text NOT NULL,
  body                text NOT NULL,
  state               public.content_state NOT NULL DEFAULT 'draft',
  approved_by_uuid    uuid,
  approved_at         timestamptz,
  published_by_uuid   uuid,
  published_at        timestamptz,
  effective_at        timestamptz,
  expires_at          timestamptz,
  created_by_uuid     uuid NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  archived_at         timestamptz,
  CONSTRAINT health_content_translation_version_uq
    UNIQUE (translation_group_uuid, version_number, language_code),
  CONSTRAINT health_content_approval_ck
    CHECK (state NOT IN ('approved', 'published') OR approved_at IS NOT NULL),
  CONSTRAINT health_content_publication_ck
    CHECK (state <> 'published' OR published_at IS NOT NULL),
  CONSTRAINT health_content_effective_range_ck
    CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at)
);

-- Empty until the privacy lead approves concrete retention periods. No invented
-- default silently deletes health data.
CREATE TABLE IF NOT EXISTS public.retention_policy (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  record_type     text NOT NULL CHECK (record_type IN (
    'resident', 'consent', 'encounter', 'follow_up',
    'hazard_report', 'health_content', 'security_audit'
  )),
  retention_days  integer NOT NULL CHECK (retention_days > 0),
  effective_at    timestamptz NOT NULL,
  created_by_uuid uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  archived_at     timestamptz
);

-- A privacy owner must approve a threshold before aggregate data is exposed.
-- No threshold is seeded because the v1.1 value is explicitly unvalidated.
CREATE TABLE IF NOT EXISTS public.aggregation_policy (
  id                      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid                    uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  metric_code             text NOT NULL CHECK (metric_code = 'barangay_encounter_summary'),
  minimum_distinct_people integer NOT NULL CHECK (minimum_distinct_people > 1),
  effective_at            timestamptz NOT NULL,
  approved_by_uuid        uuid NOT NULL,
  approved_at             timestamptz NOT NULL,
  created_by_uuid         uuid NOT NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  archived_at             timestamptz
);

-- Server-written, minimal audit metadata only; never put health values, tokens,
-- consent text, or free-form request payloads in metadata.
CREATE TABLE IF NOT EXISTS public.security_audit_event (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  actor_uuid      uuid,
  action_code     text NOT NULL,
  target_table    text NOT NULL,
  target_uuid     uuid,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS account_email_idx
  ON public.account (lower(email)) WHERE archived_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS barangay_psgc_code_live_uq
  ON public.barangay (psgc_code) WHERE psgc_code IS NOT NULL AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS community_area_barangay_live_idx
  ON public.community_area (barangay_uuid, area_type, name) WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS account_barangay_role_account_live_idx
  ON public.account_barangay_role (account_uuid) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS account_barangay_role_barangay_live_idx
  ON public.account_barangay_role (barangay_uuid, role_code, account_uuid)
  WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS account_barangay_role_one_live_uq
  ON public.account_barangay_role (account_uuid, barangay_uuid) WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS resident_barangay_live_idx
  ON public.resident (barangay_uuid) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS resident_code_barangay_live_uq
  ON public.resident (barangay_uuid, resident_code) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS consent_template_state_language_idx
  ON public.consent_template (state, language_code, effective_at, expires_at)
  WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS resident_consent_resident_decision_idx
  ON public.resident_consent (resident_uuid, purpose_code, decision_at DESC, received_at DESC)
  WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS clinical_rule_set_scope_state_idx
  ON public.clinical_rule_set (scope_code, state, effective_at, expires_at)
  WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS encounter_resident_live_idx
  ON public.encounter (resident_uuid, occurred_at DESC) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS encounter_barangay_live_idx
  ON public.encounter (barangay_uuid, occurred_at DESC) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS encounter_creator_sync_idx
  ON public.encounter (created_by_uuid, updated_at) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS encounter_observation_encounter_live_idx
  ON public.encounter_observation (encounter_uuid, field_code) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS encounter_review_one_live_uq
  ON public.encounter_review (encounter_uuid) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS encounter_review_queue_idx
  ON public.encounter_review (state, updated_at) WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS health_facility_barangay_live_idx
  ON public.health_facility (barangay_uuid, name) WHERE is_active AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS follow_up_resident_due_live_idx
  ON public.follow_up (resident_uuid, due_at) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS follow_up_assignee_due_live_idx
  ON public.follow_up (assigned_to_uuid, due_at, state) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS follow_up_encounter_live_idx
  ON public.follow_up (encounter_uuid) WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS hazard_report_barangay_date_live_idx
  ON public.hazard_report (barangay_uuid, reported_at DESC) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS hazard_report_area_category_live_idx
  ON public.hazard_report (community_area_uuid, category, reported_at DESC)
  WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS hazard_report_creator_sync_idx
  ON public.hazard_report (created_by_uuid, updated_at) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS hazard_review_one_live_uq
  ON public.hazard_review (hazard_report_uuid) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS hazard_review_queue_idx
  ON public.hazard_review (state, updated_at) WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS health_content_publication_idx
  ON public.health_content (category, language_code, effective_at, expires_at)
  WHERE state = 'published' AND archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS retention_policy_type_effective_live_uq
  ON public.retention_policy (record_type, effective_at) WHERE archived_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS aggregation_policy_metric_effective_live_uq
  ON public.aggregation_policy (metric_code, effective_at) WHERE archived_at IS NULL;
CREATE INDEX IF NOT EXISTS security_audit_target_time_idx
  ON public.security_audit_event (target_table, target_uuid, occurred_at DESC);
CREATE INDEX IF NOT EXISTS security_audit_actor_time_idx
  ON public.security_audit_event (actor_uuid, occurred_at DESC);

-- Supabase creates a profile for each Google-authenticated user. The trigger
-- copies only basic profile fields; metadata never grants roles or privileges.
CREATE OR REPLACE FUNCTION public.capsicum_bootstrap_account()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.account (uuid, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name')
  )
  ON CONFLICT (uuid) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS capsicum_auth_user_created ON auth.users;
CREATE TRIGGER capsicum_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.capsicum_bootstrap_account();

-- Authenticated client writes cannot choose or later rewrite the creator/time.
-- updated_at remains client-supplied for offline last-write-wins synchronization.
CREATE OR REPLACE FUNCTION public.capsicum_stamp_sync_attribution()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF auth.uid() IS NOT NULL THEN
      NEW.created_by_uuid := auth.uid();
    END IF;
    IF NEW.created_at IS NULL THEN
      NEW.created_at := now();
    END IF;
    IF NEW.updated_at IS NULL THEN
      NEW.updated_at := NEW.created_at;
    END IF;
  ELSE
    NEW.created_by_uuid := OLD.created_by_uuid;
    NEW.created_at := OLD.created_at;
    IF NEW.updated_at IS NULL THEN
      NEW.updated_at := OLD.updated_at;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_current_health_consent(p_resident_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE((
    SELECT rc.decision = 'granted'::public.consent_decision
    FROM public.resident_consent AS rc
    WHERE rc.resident_uuid = p_resident_uuid
      AND rc.purpose_code = 'health_encounter'
      AND rc.archived_at IS NULL
    ORDER BY rc.decision_at DESC, rc.received_at DESC
    LIMIT 1
  ), false);
$$;

CREATE OR REPLACE FUNCTION public.capsicum_guard_resident_consent()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.resident AS r
    WHERE r.uuid = NEW.resident_uuid
      AND r.archived_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Consent resident is missing or archived'
      USING ERRCODE = '23503';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.consent_template AS ct
    WHERE ct.uuid = NEW.consent_template_uuid
      AND ct.state = 'approved'
      AND ct.archived_at IS NULL
      AND (ct.effective_at IS NULL OR ct.effective_at <= NEW.decision_at)
      AND (ct.expires_at IS NULL OR ct.expires_at > NEW.decision_at)
  ) THEN
    RAISE EXCEPTION 'Consent must use an approved, effective language template'
      USING ERRCODE = '23514';
  END IF;

  NEW.received_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_guard_encounter()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.resident AS r
    WHERE r.uuid = NEW.resident_uuid
      AND r.barangay_uuid = NEW.barangay_uuid
      AND r.archived_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Encounter resident is missing, archived, or outside the barangay'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.clinical_rule_set AS crs
    WHERE crs.uuid = NEW.rule_set_uuid
      AND crs.scope_code = NEW.encounter_type_code
      AND crs.state = 'approved'
      AND crs.archived_at IS NULL
      AND (crs.effective_at IS NULL OR crs.effective_at <= NEW.occurred_at)
      AND (crs.expires_at IS NULL OR crs.expires_at > NEW.occurred_at)
  ) THEN
    RAISE EXCEPTION 'Encounter requires the approved clinical rule set for its workflow'
      USING ERRCODE = '23514';
  END IF;

  IF NOT public.capsicum_current_health_consent(NEW.resident_uuid) THEN
    RAISE EXCEPTION 'A current granted consent is required before recording health data'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_guard_observation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_resident_uuid uuid;
BEGIN
  SELECT e.resident_uuid INTO v_resident_uuid
  FROM public.encounter AS e
  WHERE e.uuid = NEW.encounter_uuid
    AND e.archived_at IS NULL;

  IF v_resident_uuid IS NULL THEN
    RAISE EXCEPTION 'Observation encounter is missing or archived'
      USING ERRCODE = '23503';
  END IF;

  IF NOT public.capsicum_current_health_consent(v_resident_uuid) THEN
    RAISE EXCEPTION 'A current granted consent is required before recording health data'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.encounter AS e
    JOIN public.clinical_rule_set AS crs ON crs.uuid = e.rule_set_uuid
    WHERE e.uuid = NEW.encounter_uuid
      AND crs.state = 'approved'
      AND crs.scope_code = e.encounter_type_code
      AND crs.archived_at IS NULL
      AND (crs.effective_at IS NULL OR crs.effective_at <= e.occurred_at)
      AND (crs.expires_at IS NULL OR crs.expires_at > e.occurred_at)
  ) THEN
    RAISE EXCEPTION 'Observation requires an approved rule set for its encounter'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_guard_hazard_area()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.community_area AS ca
    WHERE ca.uuid = NEW.community_area_uuid
      AND ca.barangay_uuid = NEW.barangay_uuid
      AND ca.archived_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Hazard report area is missing, archived, or outside the barangay'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_create_encounter_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.encounter_review (
    uuid, encounter_uuid, state, created_by_uuid, created_at, updated_at
  )
  VALUES (
    gen_random_uuid(), NEW.uuid, 'pending', NEW.created_by_uuid, NEW.created_at, NEW.updated_at
  )
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_create_hazard_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.hazard_review (
    uuid, hazard_report_uuid, state, created_by_uuid, created_at, updated_at
  )
  VALUES (
    gen_random_uuid(), NEW.uuid, 'pending', NEW.created_by_uuid, NEW.created_at, NEW.updated_at
  )
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_is_system_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.account AS a
    WHERE a.uuid = auth.uid()
      AND a.is_active
      AND a.is_system_admin
      AND a.archived_at IS NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_has_barangay_role(
  p_barangay_uuid uuid,
  p_role_codes public.barangay_role[]
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.account_barangay_role AS abr
    JOIN public.account AS a ON a.uuid = abr.account_uuid
    WHERE abr.account_uuid = auth.uid()
      AND abr.barangay_uuid = p_barangay_uuid
      AND abr.role_code = ANY (p_role_codes)
      AND abr.archived_at IS NULL
      AND a.is_active
      AND a.archived_at IS NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_manage_account(p_account_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.account_barangay_role AS target_role
    WHERE target_role.account_uuid = p_account_uuid
      AND target_role.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        target_role.barangay_uuid,
        ARRAY['administrator']::public.barangay_role[]
      )
  );
$$;

-- Administrators can onboard Contributors and Moderators only within their
-- assigned barangay. Creating or promoting System Administrators remains a
-- trusted operational action outside this RPC.
CREATE OR REPLACE FUNCTION public.capsicum_assign_barangay_role(
  p_account_uuid uuid,
  p_barangay_uuid uuid,
  p_role_code public.barangay_role
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_membership_uuid uuid;
BEGIN
  IF p_role_code = 'administrator'::public.barangay_role THEN
    RAISE EXCEPTION 'Barangay Administrators cannot grant Administrator roles'
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.capsicum_has_barangay_role(
    p_barangay_uuid, ARRAY['administrator']::public.barangay_role[]
  ) THEN
    RAISE EXCEPTION 'Administrator access to this barangay is required'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.account AS a
    WHERE a.uuid = p_account_uuid
      AND a.is_active
      AND a.archived_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Target account is unavailable'
      USING ERRCODE = '23503';
  END IF;

  INSERT INTO public.account_barangay_role (
    uuid, account_uuid, barangay_uuid, role_code, assigned_by_uuid,
    created_by_uuid, created_at, updated_at
  )
  VALUES (
    gen_random_uuid(), p_account_uuid, p_barangay_uuid, p_role_code, auth.uid(),
    auth.uid(), now(), now()
  )
  ON CONFLICT (account_uuid, barangay_uuid) WHERE archived_at IS NULL
  DO UPDATE SET
    role_code = EXCLUDED.role_code,
    assigned_by_uuid = auth.uid(),
    updated_at = now()
  RETURNING uuid INTO v_membership_uuid;

  RETURN v_membership_uuid;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_revoke_barangay_role(
  p_account_uuid uuid,
  p_barangay_uuid uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.capsicum_has_barangay_role(
    p_barangay_uuid, ARRAY['administrator']::public.barangay_role[]
  ) THEN
    RAISE EXCEPTION 'Administrator access to this barangay is required'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.account_barangay_role
  SET archived_at = now(), updated_at = now()
  WHERE account_uuid = p_account_uuid
    AND barangay_uuid = p_barangay_uuid
    AND role_code <> 'administrator'::public.barangay_role
    AND archived_at IS NULL;

  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_access_resident(p_resident_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.resident AS r
    WHERE r.uuid = p_resident_uuid
      AND r.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        r.barangay_uuid,
        ARRAY['contributor', 'moderator']::public.barangay_role[]
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_write_resident(p_resident_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.resident AS r
    WHERE r.uuid = p_resident_uuid
      AND r.created_by_uuid = auth.uid()
      AND r.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        r.barangay_uuid, ARRAY['contributor']::public.barangay_role[]
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_contribute_to_resident(p_resident_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.resident AS r
    WHERE r.uuid = p_resident_uuid
      AND r.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        r.barangay_uuid, ARRAY['contributor']::public.barangay_role[]
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_access_encounter(p_encounter_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.encounter AS e
    WHERE e.uuid = p_encounter_uuid
      AND e.archived_at IS NULL
      AND (
        (e.created_by_uuid = auth.uid()
          AND public.capsicum_has_barangay_role(
            e.barangay_uuid, ARRAY['contributor']::public.barangay_role[]
          ))
        OR public.capsicum_has_barangay_role(
          e.barangay_uuid, ARRAY['moderator']::public.barangay_role[]
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_write_encounter(p_encounter_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.encounter AS e
    WHERE e.uuid = p_encounter_uuid
      AND e.created_by_uuid = auth.uid()
      AND e.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        e.barangay_uuid, ARRAY['contributor']::public.barangay_role[]
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_review_encounter(p_encounter_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.encounter AS e
    WHERE e.uuid = p_encounter_uuid
      AND e.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        e.barangay_uuid, ARRAY['moderator']::public.barangay_role[]
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_access_hazard(p_hazard_report_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.hazard_report AS hr
    WHERE hr.uuid = p_hazard_report_uuid
      AND hr.archived_at IS NULL
      AND (
        (hr.created_by_uuid = auth.uid()
          AND public.capsicum_has_barangay_role(
            hr.barangay_uuid, ARRAY['contributor']::public.barangay_role[]
          ))
        OR public.capsicum_has_barangay_role(
          hr.barangay_uuid, ARRAY['moderator']::public.barangay_role[]
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_write_hazard(p_hazard_report_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.hazard_report AS hr
    WHERE hr.uuid = p_hazard_report_uuid
      AND hr.created_by_uuid = auth.uid()
      AND hr.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        hr.barangay_uuid, ARRAY['contributor']::public.barangay_role[]
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_review_hazard(p_hazard_report_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.hazard_report AS hr
    WHERE hr.uuid = p_hazard_report_uuid
      AND hr.archived_at IS NULL
      AND public.capsicum_has_barangay_role(
        hr.barangay_uuid, ARRAY['moderator']::public.barangay_role[]
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.capsicum_can_access_follow_up(p_follow_up_uuid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.follow_up AS f
    WHERE f.uuid = p_follow_up_uuid
      AND f.archived_at IS NULL
      AND (
        public.capsicum_can_access_encounter(f.encounter_uuid)
        OR (
          f.assigned_to_uuid = auth.uid()
          AND public.capsicum_has_barangay_role(
            (SELECT e.barangay_uuid FROM public.encounter AS e
             WHERE e.uuid = f.encounter_uuid AND e.archived_at IS NULL),
            ARRAY['contributor']::public.barangay_role[]
          )
        )
      )
  );
$$;

-- This RPC exposes only lifetime barangay aggregates and applies a fixed
-- distinct-resident threshold. It deliberately accepts no caller-supplied filters.
CREATE OR REPLACE FUNCTION public.capsicum_barangay_mvp_summary()
RETURNS TABLE (barangay_uuid uuid, resident_count bigint, encounter_count bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT e.barangay_uuid,
         count(DISTINCT e.resident_uuid),
         count(*)
  FROM public.encounter AS e
  JOIN public.account_barangay_role AS abr
    ON abr.barangay_uuid = e.barangay_uuid
   AND abr.account_uuid = auth.uid()
   AND abr.role_code = 'administrator'::public.barangay_role
   AND abr.archived_at IS NULL
  JOIN public.account AS a
    ON a.uuid = abr.account_uuid
   AND a.is_active
   AND a.archived_at IS NULL
  CROSS JOIN LATERAL (
    SELECT ap.minimum_distinct_people
    FROM public.aggregation_policy AS ap
    WHERE ap.metric_code = 'barangay_encounter_summary'
      AND ap.approved_at IS NOT NULL
      AND ap.effective_at <= now()
      AND ap.archived_at IS NULL
    ORDER BY ap.effective_at DESC
    LIMIT 1
  ) AS policy
  WHERE e.archived_at IS NULL
    AND auth.uid() IS NOT NULL
  GROUP BY e.barangay_uuid, policy.minimum_distinct_people
  HAVING count(DISTINCT e.resident_uuid) >= policy.minimum_distinct_people;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_set_review_actor()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.state IS DISTINCT FROM OLD.state OR NEW.comment IS DISTINCT FROM OLD.comment THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'A moderator session is required to change review state'
        USING ERRCODE = '42501';
    END IF;
    NEW.reviewer_uuid := auth.uid();
    NEW.reviewed_at := now();
    IF NEW.state = 'pending' THEN
      RAISE EXCEPTION 'A reviewed item cannot be reset to pending'
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_guard_follow_up()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.encounter AS e
    WHERE e.uuid = NEW.encounter_uuid
      AND e.resident_uuid = NEW.resident_uuid
      AND e.archived_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Follow-up encounter and resident do not match or are unavailable'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.destination_facility_uuid IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.health_facility AS hf
       WHERE hf.uuid = NEW.destination_facility_uuid
         AND hf.is_active
         AND hf.archived_at IS NULL
     ) THEN
    RAISE EXCEPTION 'Follow-up destination facility is unavailable'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.capsicum_stamp_completed_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.state = 'completed' AND OLD.state IS DISTINCT FROM 'completed' THEN
    NEW.completed_at := now();
  ELSIF NEW.state <> 'completed' THEN
    NEW.completed_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS capsicum_stamp_barangay ON public.barangay;
CREATE TRIGGER capsicum_stamp_barangay
BEFORE INSERT OR UPDATE ON public.barangay
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_community_area ON public.community_area;
CREATE TRIGGER capsicum_stamp_community_area
BEFORE INSERT OR UPDATE ON public.community_area
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_account_barangay_role ON public.account_barangay_role;
CREATE TRIGGER capsicum_stamp_account_barangay_role
BEFORE INSERT OR UPDATE ON public.account_barangay_role
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_resident ON public.resident;
CREATE TRIGGER capsicum_stamp_resident
BEFORE INSERT OR UPDATE ON public.resident
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_resident_consent ON public.resident_consent;
CREATE TRIGGER capsicum_stamp_resident_consent
BEFORE INSERT OR UPDATE ON public.resident_consent
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_guard_resident_consent ON public.resident_consent;
CREATE TRIGGER capsicum_guard_resident_consent
BEFORE INSERT ON public.resident_consent
FOR EACH ROW EXECUTE FUNCTION public.capsicum_guard_resident_consent();
DROP TRIGGER IF EXISTS capsicum_stamp_encounter ON public.encounter;
CREATE TRIGGER capsicum_stamp_encounter
BEFORE INSERT OR UPDATE ON public.encounter
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_encounter_observation ON public.encounter_observation;
CREATE TRIGGER capsicum_stamp_encounter_observation
BEFORE INSERT OR UPDATE ON public.encounter_observation
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_encounter_review ON public.encounter_review;
CREATE TRIGGER capsicum_stamp_encounter_review
BEFORE INSERT OR UPDATE ON public.encounter_review
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_follow_up ON public.follow_up;
CREATE TRIGGER capsicum_stamp_follow_up
BEFORE INSERT OR UPDATE ON public.follow_up
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_hazard_report ON public.hazard_report;
CREATE TRIGGER capsicum_stamp_hazard_report
BEFORE INSERT OR UPDATE ON public.hazard_report
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_hazard_review ON public.hazard_review;
CREATE TRIGGER capsicum_stamp_hazard_review
BEFORE INSERT OR UPDATE ON public.hazard_review
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();
DROP TRIGGER IF EXISTS capsicum_stamp_retention_policy ON public.retention_policy;
CREATE TRIGGER capsicum_stamp_retention_policy
BEFORE INSERT OR UPDATE ON public.retention_policy
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_sync_attribution();

DROP TRIGGER IF EXISTS capsicum_guard_encounter ON public.encounter;
CREATE TRIGGER capsicum_guard_encounter
BEFORE INSERT OR UPDATE OF resident_uuid, barangay_uuid, encounter_type_code, rule_set_uuid, occurred_at
ON public.encounter
FOR EACH ROW EXECUTE FUNCTION public.capsicum_guard_encounter();
DROP TRIGGER IF EXISTS capsicum_guard_observation ON public.encounter_observation;
CREATE TRIGGER capsicum_guard_observation
BEFORE INSERT OR UPDATE OF encounter_uuid, field_code, value_numeric, value_text, unit_code
ON public.encounter_observation
FOR EACH ROW EXECUTE FUNCTION public.capsicum_guard_observation();
DROP TRIGGER IF EXISTS capsicum_guard_hazard_area ON public.hazard_report;
CREATE TRIGGER capsicum_guard_hazard_area
BEFORE INSERT OR UPDATE OF barangay_uuid, community_area_uuid
ON public.hazard_report
FOR EACH ROW EXECUTE FUNCTION public.capsicum_guard_hazard_area();
DROP TRIGGER IF EXISTS capsicum_guard_follow_up ON public.follow_up;
CREATE TRIGGER capsicum_guard_follow_up
BEFORE INSERT OR UPDATE OF encounter_uuid, resident_uuid, destination_facility_uuid
ON public.follow_up
FOR EACH ROW EXECUTE FUNCTION public.capsicum_guard_follow_up();
DROP TRIGGER IF EXISTS capsicum_create_encounter_review ON public.encounter;
CREATE TRIGGER capsicum_create_encounter_review
AFTER INSERT ON public.encounter
FOR EACH ROW EXECUTE FUNCTION public.capsicum_create_encounter_review();
DROP TRIGGER IF EXISTS capsicum_create_hazard_review ON public.hazard_report;
CREATE TRIGGER capsicum_create_hazard_review
AFTER INSERT ON public.hazard_report
FOR EACH ROW EXECUTE FUNCTION public.capsicum_create_hazard_review();
DROP TRIGGER IF EXISTS capsicum_set_encounter_review_actor ON public.encounter_review;
CREATE TRIGGER capsicum_set_encounter_review_actor
BEFORE UPDATE ON public.encounter_review
FOR EACH ROW EXECUTE FUNCTION public.capsicum_set_review_actor();
DROP TRIGGER IF EXISTS capsicum_set_hazard_review_actor ON public.hazard_review;
CREATE TRIGGER capsicum_set_hazard_review_actor
BEFORE UPDATE ON public.hazard_review
FOR EACH ROW EXECUTE FUNCTION public.capsicum_set_review_actor();
DROP TRIGGER IF EXISTS capsicum_stamp_completed_at ON public.follow_up;
CREATE TRIGGER capsicum_stamp_completed_at
BEFORE UPDATE OF state ON public.follow_up
FOR EACH ROW EXECUTE FUNCTION public.capsicum_stamp_completed_at();

ALTER TABLE public.account ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.barangay ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_area ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_barangay_role ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resident ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_template ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinical_rule_set ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resident_consent ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encounter ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encounter_observation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encounter_review ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_facility ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follow_up ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hazard_report ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hazard_review ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retention_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aggregation_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_audit_event ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.account, public.barangay, public.community_area,
  public.account_barangay_role, public.resident, public.consent_template,
  public.clinical_rule_set,
  public.resident_consent, public.encounter, public.encounter_observation,
  public.encounter_review, public.health_facility, public.follow_up,
  public.hazard_report, public.hazard_review, public.health_content,
  public.retention_policy, public.aggregation_policy, public.security_audit_event
  FROM PUBLIC, anon, authenticated;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Grant client access by column so the server-only id is never readable,
-- writable, returned by PostgREST, or available through client-facing sequences.
GRANT SELECT (uuid, email, display_name, is_active, created_at, updated_at, archived_at)
  ON public.account TO authenticated;
GRANT SELECT (uuid, name, municipality, province, psgc_code, created_by_uuid,
  created_at, updated_at, archived_at) ON public.barangay TO authenticated;
GRANT SELECT (uuid, barangay_uuid, area_type, name, created_by_uuid,
  created_at, updated_at, archived_at) ON public.community_area TO authenticated;
GRANT SELECT (uuid, account_uuid, barangay_uuid, role_code, assigned_by_uuid,
  created_by_uuid, created_at, updated_at, archived_at)
  ON public.account_barangay_role TO authenticated;
GRANT SELECT (uuid, barangay_uuid, resident_code, created_by_uuid,
  created_at, updated_at, archived_at) ON public.resident TO authenticated;
GRANT SELECT (uuid, version_code, language_code, consent_text, state,
  approved_by_uuid, approved_at, effective_at, expires_at, created_by_uuid,
  created_at, updated_at, archived_at) ON public.consent_template TO authenticated;
GRANT SELECT (uuid, scope_code, version_code, source_title, source_url, state,
  approved_by_uuid, approved_at, effective_at, expires_at, created_by_uuid,
  created_at, updated_at, archived_at) ON public.clinical_rule_set TO authenticated;
GRANT SELECT (uuid, resident_uuid, consent_template_uuid, purpose_code, decision,
  decision_at, received_at, guardian_consent, created_by_uuid, created_at,
  updated_at, archived_at) ON public.resident_consent TO authenticated;
GRANT SELECT (uuid, resident_uuid, barangay_uuid, encounter_type_code, rule_set_uuid,
  occurred_at, created_by_uuid, created_at, updated_at, archived_at)
  ON public.encounter TO authenticated;
GRANT SELECT (uuid, encounter_uuid, field_code, value_numeric, value_text, unit_code,
  requires_review, created_by_uuid, created_at, updated_at, archived_at)
  ON public.encounter_observation TO authenticated;
GRANT SELECT (uuid, encounter_uuid, state, comment, reviewer_uuid, reviewed_at,
  created_by_uuid, created_at, updated_at, archived_at) ON public.encounter_review TO authenticated;
GRANT SELECT (uuid, barangay_uuid, name, facility_type, public_address, public_phone,
  is_active, created_by_uuid, created_at, updated_at, archived_at)
  ON public.health_facility TO authenticated;
GRANT SELECT (uuid, encounter_uuid, resident_uuid, kind, due_at, destination_facility_uuid,
  assigned_to_uuid, state, completed_at, created_by_uuid, created_at, updated_at, archived_at)
  ON public.follow_up TO authenticated;
GRANT SELECT (uuid, barangay_uuid, community_area_uuid, category, reported_at,
  created_by_uuid, created_at, updated_at, archived_at) ON public.hazard_report TO authenticated;
GRANT SELECT (uuid, hazard_report_uuid, state, comment, reviewer_uuid, reviewed_at,
  created_by_uuid, created_at, updated_at, archived_at) ON public.hazard_review TO authenticated;
GRANT SELECT (uuid, translation_group_uuid, version_number, category, language_code,
  title, body, state, approved_by_uuid, approved_at, published_by_uuid, published_at,
  effective_at, expires_at, created_by_uuid, created_at, updated_at, archived_at)
  ON public.health_content TO authenticated;
GRANT SELECT (uuid, record_type, retention_days, effective_at, created_by_uuid,
  created_at, updated_at, archived_at) ON public.retention_policy TO authenticated;
GRANT SELECT (uuid, actor_uuid, action_code, target_table, target_uuid, occurred_at, metadata)
  ON public.security_audit_event TO authenticated;

GRANT UPDATE (display_name) ON public.account TO authenticated;
GRANT INSERT (uuid, barangay_uuid, area_type, name, created_at, updated_at, archived_at)
  ON public.community_area TO authenticated;
GRANT UPDATE (barangay_uuid, area_type, name, updated_at, archived_at)
  ON public.community_area TO authenticated;
GRANT INSERT (uuid, barangay_uuid, resident_code, created_at, updated_at, archived_at)
  ON public.resident TO authenticated;
GRANT UPDATE (resident_code, updated_at, archived_at) ON public.resident TO authenticated;
GRANT INSERT (uuid, resident_uuid, consent_template_uuid, purpose_code, decision,
  decision_at, guardian_consent, created_at, updated_at, archived_at)
  ON public.resident_consent TO authenticated;
GRANT INSERT (uuid, resident_uuid, barangay_uuid, encounter_type_code, rule_set_uuid,
  occurred_at, created_at, updated_at, archived_at) ON public.encounter TO authenticated;
GRANT UPDATE (encounter_type_code, occurred_at, updated_at, archived_at)
  ON public.encounter TO authenticated;
-- Observations can affect clinical review. Only the trusted sync service writes
-- them; it must recompute requires_review from the approved rule set.
GRANT UPDATE (state, comment, updated_at) ON public.encounter_review,
  public.hazard_review TO authenticated;
GRANT INSERT (uuid, encounter_uuid, resident_uuid, kind, due_at, destination_facility_uuid,
  assigned_to_uuid, state, completed_at, created_at, updated_at, archived_at)
  ON public.follow_up TO authenticated;
GRANT UPDATE (due_at, destination_facility_uuid, assigned_to_uuid, state,
  completed_at, updated_at, archived_at) ON public.follow_up TO authenticated;
GRANT INSERT (uuid, barangay_uuid, community_area_uuid, category, reported_at,
  created_at, updated_at, archived_at) ON public.hazard_report TO authenticated;
GRANT UPDATE (community_area_uuid, category, reported_at, updated_at, archived_at)
  ON public.hazard_report TO authenticated;
GRANT INSERT (uuid, record_type, retention_days, effective_at, created_at,
  updated_at, archived_at) ON public.retention_policy TO authenticated;
GRANT UPDATE (retention_days, effective_at, updated_at, archived_at)
  ON public.retention_policy TO authenticated;
GRANT SELECT (uuid, barangay_uuid, name, facility_type, public_address, public_phone,
  is_active, created_at, updated_at) ON public.health_facility TO anon;
GRANT SELECT (uuid, translation_group_uuid, version_number, category, language_code,
  title, body, state, approved_at, published_at, effective_at, expires_at, created_at, updated_at)
  ON public.health_content TO anon;
GRANT ALL ON public.account, public.barangay, public.community_area,
  public.account_barangay_role, public.resident, public.consent_template,
  public.clinical_rule_set,
  public.resident_consent, public.encounter, public.encounter_observation,
  public.encounter_review, public.health_facility, public.follow_up,
  public.hazard_report, public.hazard_review, public.health_content,
  public.retention_policy, public.aggregation_policy,
  public.security_audit_event TO service_role;
REVOKE ALL ON SEQUENCE
  public.account_id_seq,
  public.barangay_id_seq,
  public.community_area_id_seq,
  public.account_barangay_role_id_seq,
  public.resident_id_seq,
  public.consent_template_id_seq,
  public.clinical_rule_set_id_seq,
  public.resident_consent_id_seq,
  public.encounter_id_seq,
  public.encounter_observation_id_seq,
  public.encounter_review_id_seq,
  public.health_facility_id_seq,
  public.follow_up_id_seq,
  public.hazard_report_id_seq,
  public.hazard_review_id_seq,
  public.health_content_id_seq,
  public.retention_policy_id_seq,
  public.aggregation_policy_id_seq,
  public.security_audit_event_id_seq FROM PUBLIC, anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE
  public.account_id_seq,
  public.barangay_id_seq,
  public.community_area_id_seq,
  public.account_barangay_role_id_seq,
  public.resident_id_seq,
  public.consent_template_id_seq,
  public.clinical_rule_set_id_seq,
  public.resident_consent_id_seq,
  public.encounter_id_seq,
  public.encounter_observation_id_seq,
  public.encounter_review_id_seq,
  public.health_facility_id_seq,
  public.follow_up_id_seq,
  public.hazard_report_id_seq,
  public.hazard_review_id_seq,
  public.health_content_id_seq,
  public.retention_policy_id_seq,
  public.aggregation_policy_id_seq,
  public.security_audit_event_id_seq TO service_role;

REVOKE ALL ON FUNCTION public.capsicum_bootstrap_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_stamp_sync_attribution() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_current_health_consent(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_guard_encounter() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_guard_observation() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_guard_hazard_area() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_create_encounter_review() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_create_hazard_review() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_guard_resident_consent() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_is_system_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_has_barangay_role(uuid, public.barangay_role[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_manage_account(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_assign_barangay_role(
  uuid, uuid, public.barangay_role
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_revoke_barangay_role(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_access_resident(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_write_resident(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_contribute_to_resident(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_access_encounter(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_write_encounter(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_review_encounter(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_access_hazard(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_write_hazard(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_review_hazard(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_can_access_follow_up(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_barangay_mvp_summary() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_set_review_actor() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_guard_follow_up() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.capsicum_stamp_completed_at() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.capsicum_is_system_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_has_barangay_role(uuid, public.barangay_role[])
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_manage_account(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_assign_barangay_role(
  uuid, uuid, public.barangay_role
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_revoke_barangay_role(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_access_resident(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_write_resident(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_contribute_to_resident(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_access_encounter(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_write_encounter(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_review_encounter(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_access_hazard(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_write_hazard(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_review_hazard(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_can_access_follow_up(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capsicum_barangay_mvp_summary() TO authenticated;

DROP POLICY IF EXISTS account_select_scoped ON public.account;
CREATE POLICY account_select_scoped ON public.account
FOR SELECT TO authenticated
USING (uuid = auth.uid() OR public.capsicum_can_manage_account(uuid));
DROP POLICY IF EXISTS account_update_self ON public.account;
CREATE POLICY account_update_self ON public.account
FOR UPDATE TO authenticated
USING (uuid = auth.uid() AND is_active AND archived_at IS NULL)
WITH CHECK (uuid = auth.uid() AND is_active AND archived_at IS NULL);

DROP POLICY IF EXISTS barangay_select_assigned ON public.barangay;
CREATE POLICY barangay_select_assigned ON public.barangay
FOR SELECT TO authenticated
USING (
  archived_at IS NULL
  AND public.capsicum_has_barangay_role(
    uuid, ARRAY['administrator', 'moderator', 'contributor']::public.barangay_role[]
  )
);

DROP POLICY IF EXISTS community_area_select_assigned ON public.community_area;
CREATE POLICY community_area_select_assigned ON public.community_area
FOR SELECT TO authenticated
USING (
  archived_at IS NULL
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['administrator', 'moderator', 'contributor']::public.barangay_role[]
  )
);
DROP POLICY IF EXISTS community_area_insert_admin ON public.community_area;
CREATE POLICY community_area_insert_admin ON public.community_area
FOR INSERT TO authenticated
WITH CHECK (
  public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['administrator']::public.barangay_role[]
  )
);
DROP POLICY IF EXISTS community_area_update_admin ON public.community_area;
CREATE POLICY community_area_update_admin ON public.community_area
FOR UPDATE TO authenticated
USING (
  archived_at IS NULL
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['administrator']::public.barangay_role[]
  )
)
WITH CHECK (
  public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['administrator']::public.barangay_role[]
  )
);

DROP POLICY IF EXISTS account_barangay_role_select_scoped ON public.account_barangay_role;
CREATE POLICY account_barangay_role_select_scoped ON public.account_barangay_role
FOR SELECT TO authenticated
USING (
  archived_at IS NULL
  AND (
    account_uuid = auth.uid()
    OR public.capsicum_has_barangay_role(
      barangay_uuid, ARRAY['administrator']::public.barangay_role[]
    )
  )
);
-- Role assignments are changed through a trusted server operation that validates
-- the caller's Administrator scope. No direct client INSERT/UPDATE/DELETE grant.

DROP POLICY IF EXISTS resident_select_assigned ON public.resident;
CREATE POLICY resident_select_assigned ON public.resident
FOR SELECT TO authenticated
USING (public.capsicum_can_access_resident(uuid));
DROP POLICY IF EXISTS resident_insert_contributor ON public.resident;
CREATE POLICY resident_insert_contributor ON public.resident
FOR INSERT TO authenticated
WITH CHECK (
  archived_at IS NULL
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['contributor']::public.barangay_role[]
  )
);
DROP POLICY IF EXISTS resident_update_creator ON public.resident;
CREATE POLICY resident_update_creator ON public.resident
FOR UPDATE TO authenticated
USING (public.capsicum_can_write_resident(uuid))
WITH CHECK (
  created_by_uuid = auth.uid()
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['contributor']::public.barangay_role[]
  )
);

DROP POLICY IF EXISTS consent_template_select_approved ON public.consent_template;
CREATE POLICY consent_template_select_approved ON public.consent_template
FOR SELECT TO authenticated
USING (
  state = 'approved'
  AND archived_at IS NULL
  AND (effective_at IS NULL OR effective_at <= now())
  AND (expires_at IS NULL OR expires_at > now())
);

DROP POLICY IF EXISTS clinical_rule_set_select_approved ON public.clinical_rule_set;
CREATE POLICY clinical_rule_set_select_approved ON public.clinical_rule_set
FOR SELECT TO authenticated
USING (
  state = 'approved'
  AND archived_at IS NULL
  AND (effective_at IS NULL OR effective_at <= now())
  AND (expires_at IS NULL OR expires_at > now())
);

DROP POLICY IF EXISTS resident_consent_select_scoped ON public.resident_consent;
CREATE POLICY resident_consent_select_scoped ON public.resident_consent
FOR SELECT TO authenticated
USING (
  created_by_uuid = auth.uid()
  OR public.capsicum_can_access_resident(resident_uuid)
);
DROP POLICY IF EXISTS resident_consent_insert_contributor ON public.resident_consent;
CREATE POLICY resident_consent_insert_contributor ON public.resident_consent
FOR INSERT TO authenticated
WITH CHECK (
  archived_at IS NULL
  AND public.capsicum_can_contribute_to_resident(resident_uuid)
);

DROP POLICY IF EXISTS encounter_select_scoped ON public.encounter;
CREATE POLICY encounter_select_scoped ON public.encounter
FOR SELECT TO authenticated
USING (public.capsicum_can_access_encounter(uuid));
DROP POLICY IF EXISTS encounter_insert_contributor ON public.encounter;
CREATE POLICY encounter_insert_contributor ON public.encounter
FOR INSERT TO authenticated
WITH CHECK (
  archived_at IS NULL
  AND public.capsicum_can_contribute_to_resident(resident_uuid)
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['contributor']::public.barangay_role[]
  )
);
DROP POLICY IF EXISTS encounter_update_creator ON public.encounter;
CREATE POLICY encounter_update_creator ON public.encounter
FOR UPDATE TO authenticated
USING (public.capsicum_can_write_encounter(uuid))
WITH CHECK (
  created_by_uuid = auth.uid()
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['contributor']::public.barangay_role[]
  )
);

DROP POLICY IF EXISTS encounter_observation_select_scoped ON public.encounter_observation;
CREATE POLICY encounter_observation_select_scoped ON public.encounter_observation
FOR SELECT TO authenticated
USING (public.capsicum_can_access_encounter(encounter_uuid));
DROP POLICY IF EXISTS encounter_observation_insert_contributor ON public.encounter_observation;
DROP POLICY IF EXISTS encounter_observation_update_contributor ON public.encounter_observation;

DROP POLICY IF EXISTS encounter_review_select_scoped ON public.encounter_review;
CREATE POLICY encounter_review_select_scoped ON public.encounter_review
FOR SELECT TO authenticated
USING (public.capsicum_can_access_encounter(encounter_uuid));
DROP POLICY IF EXISTS encounter_review_insert_moderator ON public.encounter_review;
CREATE POLICY encounter_review_insert_moderator ON public.encounter_review
FOR INSERT TO authenticated
WITH CHECK (public.capsicum_can_review_encounter(encounter_uuid));
DROP POLICY IF EXISTS encounter_review_update_moderator ON public.encounter_review;
CREATE POLICY encounter_review_update_moderator ON public.encounter_review
FOR UPDATE TO authenticated
USING (public.capsicum_can_review_encounter(encounter_uuid))
WITH CHECK (public.capsicum_can_review_encounter(encounter_uuid));

DROP POLICY IF EXISTS health_facility_select_public ON public.health_facility;
CREATE POLICY health_facility_select_public ON public.health_facility
FOR SELECT TO anon, authenticated
USING (is_active AND archived_at IS NULL);

DROP POLICY IF EXISTS follow_up_select_scoped ON public.follow_up;
CREATE POLICY follow_up_select_scoped ON public.follow_up
FOR SELECT TO authenticated
USING (public.capsicum_can_access_follow_up(uuid));
DROP POLICY IF EXISTS follow_up_insert_contributor ON public.follow_up;
CREATE POLICY follow_up_insert_contributor ON public.follow_up
FOR INSERT TO authenticated
WITH CHECK (
  archived_at IS NULL
  AND created_by_uuid = auth.uid()
  AND public.capsicum_can_write_encounter(encounter_uuid)
);
DROP POLICY IF EXISTS follow_up_update_assigned ON public.follow_up;
CREATE POLICY follow_up_update_assigned ON public.follow_up
FOR UPDATE TO authenticated
USING (
  public.capsicum_can_access_follow_up(uuid)
)
WITH CHECK (
  public.capsicum_can_access_follow_up(uuid)
);

DROP POLICY IF EXISTS hazard_report_select_scoped ON public.hazard_report;
CREATE POLICY hazard_report_select_scoped ON public.hazard_report
FOR SELECT TO authenticated
USING (public.capsicum_can_access_hazard(uuid));
DROP POLICY IF EXISTS hazard_report_insert_contributor ON public.hazard_report;
CREATE POLICY hazard_report_insert_contributor ON public.hazard_report
FOR INSERT TO authenticated
WITH CHECK (
  archived_at IS NULL
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['contributor']::public.barangay_role[]
  )
);
DROP POLICY IF EXISTS hazard_report_update_creator ON public.hazard_report;
CREATE POLICY hazard_report_update_creator ON public.hazard_report
FOR UPDATE TO authenticated
USING (public.capsicum_can_write_hazard(uuid))
WITH CHECK (
  created_by_uuid = auth.uid()
  AND public.capsicum_has_barangay_role(
    barangay_uuid, ARRAY['contributor']::public.barangay_role[]
  )
);

DROP POLICY IF EXISTS hazard_review_select_scoped ON public.hazard_review;
CREATE POLICY hazard_review_select_scoped ON public.hazard_review
FOR SELECT TO authenticated
USING (
  public.capsicum_can_review_hazard(hazard_report_uuid)
  OR EXISTS (
    SELECT 1 FROM public.hazard_report AS hr
    WHERE hr.uuid = hazard_report_uuid
      AND hr.created_by_uuid = auth.uid()
      AND public.capsicum_can_access_hazard(hr.uuid)
  )
);
DROP POLICY IF EXISTS hazard_review_insert_moderator ON public.hazard_review;
CREATE POLICY hazard_review_insert_moderator ON public.hazard_review
FOR INSERT TO authenticated
WITH CHECK (public.capsicum_can_review_hazard(hazard_report_uuid));
DROP POLICY IF EXISTS hazard_review_update_moderator ON public.hazard_review;
CREATE POLICY hazard_review_update_moderator ON public.hazard_review
FOR UPDATE TO authenticated
USING (public.capsicum_can_review_hazard(hazard_report_uuid))
WITH CHECK (public.capsicum_can_review_hazard(hazard_report_uuid));

DROP POLICY IF EXISTS health_content_select_public ON public.health_content;
CREATE POLICY health_content_select_public ON public.health_content
FOR SELECT TO anon, authenticated
USING (
  state = 'published'
  AND archived_at IS NULL
  AND (effective_at IS NULL OR effective_at <= now())
  AND (expires_at IS NULL OR expires_at > now())
);

DROP POLICY IF EXISTS retention_policy_select_system_admin ON public.retention_policy;
CREATE POLICY retention_policy_select_system_admin ON public.retention_policy
FOR SELECT TO authenticated
USING (archived_at IS NULL AND public.capsicum_is_system_admin());
DROP POLICY IF EXISTS retention_policy_insert_system_admin ON public.retention_policy;
CREATE POLICY retention_policy_insert_system_admin ON public.retention_policy
FOR INSERT TO authenticated
WITH CHECK (
  archived_at IS NULL
  AND public.capsicum_is_system_admin()
  AND created_by_uuid = auth.uid()
);
DROP POLICY IF EXISTS retention_policy_update_system_admin ON public.retention_policy;
CREATE POLICY retention_policy_update_system_admin ON public.retention_policy
FOR UPDATE TO authenticated
USING (archived_at IS NULL AND public.capsicum_is_system_admin())
WITH CHECK (
  public.capsicum_is_system_admin()
);

DROP POLICY IF EXISTS security_audit_select_system_admin ON public.security_audit_event;
CREATE POLICY security_audit_select_system_admin ON public.security_audit_event
FOR SELECT TO authenticated
USING (public.capsicum_is_system_admin());

COMMIT;
