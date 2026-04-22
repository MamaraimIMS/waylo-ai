-- ============================================================================
-- WayloAI · PostgreSQL schema v1.1 for Supabase
-- Transfer Intelligence Platform
-- ============================================================================
-- Применение:
--   1. Откройте Supabase Dashboard → SQL Editor
--   2. Вставьте содержимое этого файла целиком
--   3. Нажмите Run (Ctrl+Enter)
--   4. Должно создаться 10 таблиц, 6 ENUM, 2 функции, 2 view, seed data
-- ============================================================================

-- Supabase уже имеет встроенные расширения, но убедимся
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ENUMS
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('dmc_admin', 'dmc_operator', 'driver', 'dispatcher', 'superadmin', 'finance');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE vehicle_category AS ENUM ('sedan', 'minivan', 'van', 'midibus', 'bus');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE request_status AS ENUM ('received', 'parsing', 'parsed', 'validated', 'dispatching', 'confirmed', 'in_progress', 'completed', 'cancelled', 'failed');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE assignment_status AS ENUM ('pending', 'sent', 'confirmed', 'declined', 'expired', 'cancelled', 'completed');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE city_code AS ENUM ('tashkent', 'samarkand', 'bukhara', 'khiva', 'urganch', 'gijduvan', 'fergana', 'namangan', 'andijan', 'termez', 'nukus');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE slot_status AS ENUM ('free', 'blocked', 'booked', 'tentative');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ============================================================================
-- DMC COMPANIES
-- ============================================================================
CREATE TABLE IF NOT EXISTS dmc_companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  country_code CHAR(2) DEFAULT 'UZ',
  contact_email TEXT,
  subscription_tier TEXT DEFAULT 'basic',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- USERS
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  phone TEXT UNIQUE,
  full_name TEXT NOT NULL,
  role user_role NOT NULL,
  dmc_id UUID REFERENCES dmc_companies(id) ON DELETE SET NULL,
  telegram_id BIGINT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_users_dmc ON users(dmc_id) WHERE dmc_id IS NOT NULL;

-- ============================================================================
-- DRIVERS
-- ============================================================================
CREATE TABLE IF NOT EXISTS drivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  home_city city_code NOT NULL,
  working_cities city_code[] DEFAULT ARRAY[]::city_code[],
  driver_license_number TEXT NOT NULL,
  rating NUMERIC(3,2) DEFAULT 5.00 CHECK (rating >= 0 AND rating <= 5),
  trips_completed INTEGER DEFAULT 0,
  is_suspended BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_drivers_city ON drivers(home_city) WHERE is_suspended = FALSE;
CREATE INDEX IF NOT EXISTS idx_drivers_rating ON drivers(rating DESC) WHERE is_suspended = FALSE;

-- ============================================================================
-- VEHICLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  category vehicle_category NOT NULL,
  make TEXT NOT NULL,
  model TEXT NOT NULL,
  license_plate TEXT UNIQUE NOT NULL,
  capacity_pax SMALLINT NOT NULL CHECK (capacity_pax BETWEEN 1 AND 60),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_driver ON vehicles(driver_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_vehicles_category ON vehicles(category) WHERE is_active = TRUE;

-- ============================================================================
-- CALENDAR SLOTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS calendar_slots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  slot_date DATE NOT NULL,
  status slot_status NOT NULL DEFAULT 'free',
  assignment_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(driver_id, slot_date)
);

CREATE INDEX IF NOT EXISTS idx_slots_driver_date ON calendar_slots(driver_id, slot_date);

-- ============================================================================
-- TRANSFER REQUESTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS transfer_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  external_id TEXT UNIQUE,
  dmc_id UUID NOT NULL REFERENCES dmc_companies(id),
  tour_name TEXT NOT NULL,
  pax_count SMALLINT NOT NULL CHECK (pax_count > 0),
  vehicle_category vehicle_category NOT NULL,
  status request_status NOT NULL DEFAULT 'received',
  source_file_name TEXT,
  source_file_type TEXT,
  ai_confidence NUMERIC(4,3),
  parse_duration_ms INTEGER,
  parse_raw_output JSONB,
  total_segments SMALLINT DEFAULT 0,
  total_days SMALLINT DEFAULT 0,
  cities_covered city_code[] DEFAULT ARRAY[]::city_code[],
  tour_starts_on DATE,
  tour_ends_on DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_requests_dmc ON transfer_requests(dmc_id);
CREATE INDEX IF NOT EXISTS idx_requests_status ON transfer_requests(status);
CREATE INDEX IF NOT EXISTS idx_requests_dates ON transfer_requests(tour_starts_on, tour_ends_on);

-- ============================================================================
-- TRANSFER SEGMENTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS transfer_segments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES transfer_requests(id) ON DELETE CASCADE,
  day_number SMALLINT NOT NULL,
  transfer_date DATE NOT NULL,
  sequence SMALLINT NOT NULL,
  time_from TIME NOT NULL,
  time_to TIME NOT NULL,
  travel_duration_minutes INTEGER NOT NULL,
  location_from TEXT NOT NULL,
  location_to TEXT NOT NULL,
  city_from city_code NOT NULL,
  city_to city_code NOT NULL,
  dispatch_city city_code NOT NULL,
  is_intercity BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_segments_request ON transfer_segments(request_id, day_number, sequence);
CREATE INDEX IF NOT EXISTS idx_segments_dispatch ON transfer_segments(dispatch_city, transfer_date);

-- ============================================================================
-- DRIVER ASSIGNMENTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS driver_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id UUID NOT NULL REFERENCES transfer_requests(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id),
  segment_ids UUID[] NOT NULL,
  dispatch_city city_code NOT NULL,
  assignment_date DATE NOT NULL,
  status assignment_status NOT NULL DEFAULT 'pending',
  notification_sent_at TIMESTAMPTZ,
  confirmed_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  decline_reason TEXT,
  expires_at TIMESTAMPTZ,
  tier SMALLINT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assignments_request ON driver_assignments(request_id);
CREATE INDEX IF NOT EXISTS idx_assignments_driver ON driver_assignments(driver_id, assignment_date);
CREATE INDEX IF NOT EXISTS idx_assignments_status ON driver_assignments(status)
  WHERE status IN ('pending', 'sent', 'confirmed');

-- ============================================================================
-- AUDIT LOG
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
  id BIGSERIAL PRIMARY KEY,
  actor_user_id UUID REFERENCES users(id),
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL,
  before_state JSONB,
  after_state JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log(entity_type, entity_id, created_at DESC);

-- ============================================================================
-- FUNCTION · classify_vehicle_by_pax
-- ============================================================================
CREATE OR REPLACE FUNCTION classify_vehicle_by_pax(p_pax SMALLINT)
RETURNS vehicle_category AS $$
BEGIN
  RETURN CASE
    WHEN p_pax <= 2 THEN 'sedan'::vehicle_category
    WHEN p_pax <= 4 THEN 'minivan'::vehicle_category
    WHEN p_pax <= 8 THEN 'van'::vehicle_category
    WHEN p_pax <= 12 THEN 'midibus'::vehicle_category
    ELSE 'bus'::vehicle_category
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- FUNCTION · find_available_drivers
-- ============================================================================
CREATE OR REPLACE FUNCTION find_available_drivers(
  p_city city_code,
  p_date DATE,
  p_vehicle_category vehicle_category,
  p_pax SMALLINT DEFAULT NULL,
  p_limit INTEGER DEFAULT 5
) RETURNS TABLE (
  driver_id UUID,
  full_name TEXT,
  rating NUMERIC,
  trips_completed INTEGER,
  vehicle_id UUID,
  license_plate TEXT,
  capacity_pax SMALLINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id, u.full_name, d.rating, d.trips_completed,
    v.id, v.license_plate, v.capacity_pax
  FROM drivers d
  JOIN users u ON u.id = d.user_id
  JOIN vehicles v ON v.driver_id = d.id
  WHERE (d.home_city = p_city OR p_city = ANY(d.working_cities))
    AND d.is_suspended = FALSE
    AND u.is_active = TRUE
    AND v.is_active = TRUE
    AND v.category = p_vehicle_category
    AND (p_pax IS NULL OR v.capacity_pax >= p_pax)
    AND NOT EXISTS (
      SELECT 1 FROM calendar_slots cs
      WHERE cs.driver_id = d.id
        AND cs.slot_date = p_date
        AND cs.status IN ('booked', 'blocked')
    )
  ORDER BY d.rating DESC, d.trips_completed DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGER · auto-block calendar on confirmation
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_block_calendar_on_confirm() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status <> 'confirmed') THEN
    INSERT INTO calendar_slots (driver_id, slot_date, status, assignment_id)
    VALUES (NEW.driver_id, NEW.assignment_date, 'booked', NEW.id)
    ON CONFLICT (driver_id, slot_date) DO UPDATE
      SET status = 'booked', assignment_id = NEW.id, updated_at = NOW();
  END IF;

  IF NEW.status IN ('cancelled', 'declined') AND OLD.status = 'confirmed' THEN
    UPDATE calendar_slots SET status = 'free', assignment_id = NULL, updated_at = NOW()
    WHERE assignment_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_calendar ON driver_assignments;
CREATE TRIGGER trg_block_calendar
  AFTER INSERT OR UPDATE OF status ON driver_assignments
  FOR EACH ROW EXECUTE FUNCTION fn_block_calendar_on_confirm();

-- ============================================================================
-- VIEWS
-- ============================================================================
CREATE OR REPLACE VIEW v_active_requests AS
SELECT
  r.id, r.external_id, r.tour_name, r.pax_count, r.vehicle_category,
  r.status, r.tour_starts_on, r.tour_ends_on, r.total_segments,
  r.ai_confidence, r.created_at,
  d.name AS dmc_name,
  COUNT(DISTINCT a.id) AS total_assignments,
  COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'confirmed') AS confirmed_assignments
FROM transfer_requests r
JOIN dmc_companies d ON d.id = r.dmc_id
LEFT JOIN driver_assignments a ON a.request_id = r.id
WHERE r.status NOT IN ('completed', 'cancelled', 'failed')
GROUP BY r.id, d.name;

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- DMC companies
INSERT INTO dmc_companies (id, name, country_code, contact_email, subscription_tier) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Advantour', 'UZ', 'tours@advantour.com', 'premium'),
  ('22222222-2222-2222-2222-222222222222', 'East Line Tour', 'UZ', 'info@eastlinetour.com', 'basic'),
  ('33333333-3333-3333-3333-333333333333', 'Silk Road Destinations', 'UZ', 'hello@silkroad-dest.com', 'premium')
ON CONFLICT DO NOTHING;

-- Test dispatcher user (needed for n8n to reference created_by)
INSERT INTO users (id, email, full_name, role, dmc_id) VALUES
  ('00000000-0000-0000-0000-000000000001', 'dispatcher@waylo.ai', 'System Dispatcher', 'dispatcher', NULL)
ON CONFLICT DO NOTHING;

-- Test drivers
INSERT INTO users (id, email, full_name, role) VALUES
  ('10000000-0000-0000-0000-000000000001', 'abdullaev@example.com', 'Abdullaev Bakhtiyor', 'driver'),
  ('10000000-0000-0000-0000-000000000002', 'yuldashev@example.com', 'Yuldashev Bobur', 'driver'),
  ('10000000-0000-0000-0000-000000000003', 'zubaev@example.com', 'Zubaev Umid', 'driver'),
  ('10000000-0000-0000-0000-000000000004', 'smirnov@example.com', 'Smirnov Konstantin', 'driver')
ON CONFLICT DO NOTHING;

INSERT INTO drivers (id, user_id, home_city, driver_license_number, rating, trips_completed) VALUES
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'tashkent', 'AB1234567', 4.9, 312),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'khiva', 'YU7654321', 4.8, 198),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'bukhara', 'ZU9876543', 4.9, 247),
  ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000004', 'samarkand', 'SM5432109', 4.7, 156)
ON CONFLICT DO NOTHING;

INSERT INTO vehicles (id, driver_id, category, make, model, license_plate, capacity_pax) VALUES
  ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'sedan', 'Mercedes', 'Sprinter', '01 B 070 CA', 15),
  ('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'sedan', 'Mercedes', 'Sprinter', '90 C 110 KL', 15),
  ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 'sedan', 'Hyundai', 'Staria', '40 A 233 BH', 8),
  ('30000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000004', 'sedan', 'Toyota', 'Hiace', '30 H 445 SM', 12)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- ROW LEVEL SECURITY (включите когда добавите auth)
-- ============================================================================
-- ALTER TABLE transfer_requests ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE driver_assignments ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE calendar_slots ENABLE ROW LEVEL SECURITY;
-- Policies создавайте после того, как настроите Supabase Auth

-- ============================================================================
-- READY!
-- Следующий шаг: импортируйте n8n workflow и подключите credentials.
-- См. docs/02-setup-n8n.md
-- ============================================================================
