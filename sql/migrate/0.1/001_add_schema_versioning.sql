-- get_schema_type()
-- returns the type of the schema
-- This is used for identifying the schema type in a multi-schema environment.
-- By default it returns 'core' for the core schema - but it can be changed to 
-- any relevant name to describe your schema when you have more than one.
-- SELECT get_schema_type() as type;
-- core
CREATE OR REPLACE FUNCTION get_schema_type()
    RETURNS TABLE (type VARCHAR)
AS $$
    -- update this to reflect the name of schema/db you are using
    SELECT 'core';
$$
LANGUAGE SQL;


-- Create versioning schema with history for storing schema versions
-- This table will keep track of the schema versions applied to the database.
-- It is useful for migrations and understanding the evolution of the schema.
-- You can query it - but use the set_schema_version() and get_schema_version()
-- functions to manage the schema versioning.
CREATE TABLE db_schema_version (
    id SERIAL PRIMARY KEY,
    creation_date TIMESTAMP NOT NULL,
    major INTEGER NOT NULL,
    minor INTEGER NOT NULL,
    patch INTEGER NOT NULL
);


-- get_schema_version()
-- Function to get the schema version as a string
-- SELECT get_schema_version() as version;
-- 0.0.1
-- This function retrieves the latest schema version from the db_schema_version table.
-- It returns the version in the format 'major.minor.patch'.
-- It makes it easy to check the current schema version in scripts or from the 
-- application.  It is recommended to use this function to check the schema version
-- before applying migrations.
CREATE OR REPLACE FUNCTION get_schema_version()
    RETURNS TABLE (type VARCHAR)
AS $$
    SELECT CONCAT(major
            ,'.', minor
            ,'.', patch) FROM db_schema_version
    ORDER BY id DESC
    LIMIT 1;
$$
LANGUAGE SQL;


-- set_schema_version(x,y,z)
-- Function to set schema version
-- This function is used to set the schema version in the db_schema_version table.
-- It is called after applying a migration to update the schema version.
-- CALL set_schema_version(0,0,1);
CREATE OR REPLACE PROCEDURE set_schema_version(
    major INT,
    minor INT,
    patch INT)
LANGUAGE PLPGSQL
AS
$$
BEGIN
    INSERT INTO db_schema_version
        (creation_date, major, minor, patch)
    VALUES (NOW(), major, minor, patch);
END;
$$;

-- Set the version number:
CALL set_schema_version(0,1,1);
