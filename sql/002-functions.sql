BEGIN;

CREATE OR REPLACE FUNCTION set_server (
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

CREATE OR REPLACE FUNCTION set_channel (
    a_server  CITEXT,
    a_channel CITEXT
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
    PERFORM TRUE FROM channels WHERE server = a_server AND name = a_channel;
    IF NOT FOUND THEN
        PERFORM set_server(a_server);
        INSERT INTO channels (server, name) VALUES (a_server, a_channel);
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
    SELECT set_channel($1, $2);
    INSERT INTO messages ( server, channel, nick, command, body )
    VALUES ( $1, $2, $3, $4, $5 )
    RETURNING TRUE;
$$;

COMMIT;
