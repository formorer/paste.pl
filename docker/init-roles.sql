DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'www-data') THEN
        CREATE ROLE "www-data" LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        CREATE ROLE "postgres" SUPERUSER LOGIN;
    END IF;
END$$;
