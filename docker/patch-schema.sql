-- Patch schema revoke/grant to skip missing roles when running in CI/Docker
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        CREATE ROLE "postgres" SUPERUSER LOGIN;
    END IF;
END$$;
