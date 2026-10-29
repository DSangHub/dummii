-- Enable PostGIS extension for spatial matching
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Merchants Table
CREATE TABLE merchants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_name TEXT NOT NULL,
  category TEXT NOT NULL, -- e.g., 'Auto', 'Grocery', 'Hardware'
  address TEXT NOT NULL,
  location GEOGRAPHY(Point, 4326) NOT NULL, -- Lat/Lng coordinates
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index for fast proximity lookups
CREATE INDEX merchants_location_idx ON merchants USING GIST (location);

-- 2. Merchant Bids Table
CREATE TABLE merchant_bids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
  item_keywords TEXT[] NOT NULL, -- e.g., ['tires', 'hyundai', 'installation']
  title TEXT NOT NULL,
  regular_price NUMERIC(10, 2) NOT NULL,
  offer_price NUMERIC(10, 2) NOT NULL,
  buy_now_url TEXT NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to find nearby bids based on query and user coordinates
CREATE OR REPLACE FUNCTION find_nearby_bids(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_meters DOUBLE PRECISION DEFAULT 16093.4 -- Default 10 miles
)
RETURNS TABLE (
  bid_id UUID,
  business_name TEXT,
  title TEXT,
  regular_price NUMERIC,
  offer_price NUMERIC,
  buy_now_url TEXT,
  distance_miles DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id AS bid_id,
    m.business_name,
    b.title,
    b.regular_price,
    b.offer_price,
    b.buy_now_url,
    ST_Distance(m.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography) / 1609.34 AS distance_miles
  FROM merchant_bids b
  JOIN merchants m ON b.merchant_id = m.id
  WHERE b.active = TRUE
    AND ST_DWithin(m.location, ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography, radius_meters)
  ORDER BY b.offer_price ASC;
END;
$$ LANGUAGE plpgsql;
