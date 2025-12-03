-- Skip revoking privileges from postgres role (not present in minimal init)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        REVOKE ALL ON SCHEMA public FROM postgres;
    END IF;
END$$;
