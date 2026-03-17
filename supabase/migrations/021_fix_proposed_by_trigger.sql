-- 021_fix_proposed_by_trigger.sql
-- Fix fn_force_proposed_by: auth.uid()::text → auth.jwt()->>'sub'
-- auth.uid() requires UUID format. Our user IDs are text (phone_XXXXXXXXXX).

CREATE OR REPLACE FUNCTION fn_force_proposed_by()
RETURNS TRIGGER AS $$
BEGIN
  -- Service role can set proposed_by directly
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- For authenticated users, force proposed_by to their JWT sub
  NEW.proposed_by := auth.jwt()->>'sub';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
