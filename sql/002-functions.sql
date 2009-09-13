SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET client_min_messages = warning;

BEGIN;

CREATE OR REPLACE FUNCTION check_server (
    a_server  CITEXT
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    PERFORM TRUE FROM servers WHERE name = a_server;
    IF NOT FOUND THEN
        INSERT INTO servers (name) VALUES (a_server);
    END IF;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION check_references (
    a_server  CITEXT,
    a_channel CITEXT,
    a_nick    CITEXT
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
DECLARE
    d_got_server BOOLEAN := false;
BEGIN
    PERFORM TRUE FROM channels WHERE server = a_server AND name = a_channel;
    IF NOT FOUND THEN
        d_got_server := check_server(a_server);
        INSERT INTO channels (server, name) VALUES (a_server, a_channel);
    END IF;

    PERFORM TRUE FROM nicks WHERE server = a_server AND name = a_nick;
    IF NOT FOUND THEN
        IF NOT d_got_server THEN PERFORM check_server(a_server); END IF;
        INSERT INTO nicks (server, name) VALUES (a_server, a_nick);
    END IF;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION add_message(
    a_server   CITEXT,
    a_channel  CITEXT,
    a_nick     CITEXT,
    a_command  COMMAND,
    a_body     TEXT
) RETURNS BOOLEAN LANGUAGE SQL AS $$
    SELECT check_references($1, $2, $3);
    INSERT INTO messages ( server, channel, nick, command, body )
    VALUES ( $1, $2, $3, $4, $5 )
    RETURNING TRUE;
$$;

COMMIT;
