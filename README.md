# Listening PostgreSQL Logical Replication

This repo contains an example in the [example folder](/examples/) for listening to Postgresql Logical Replication. This allows listening to changes in PostgreSQL database in the following manner:

- Insert changes (one row):
    ```json
    {
        "change": [
                {
                    "kind": "insert",
                    "schema": "public",
                    "table": "temp",
                    "columnnames": ["id", "val"],
                    "columntypes": ["integer", "text"],
                    "columnvalues": [58, "new value"]
                }
        ]
    }
    ```

- Update changes (two rows):
    ```json
    {
        "change": [
                {
                        "kind": "update",
                        "schema": "public",
                        "table": "temp",
                        "columnnames": ["id", "val"],
                        "columntypes": ["integer", "text"],
                        "columnvalues": [2, "updated value"],
                        "oldkeys": {
                                "keynames": ["id"],
                                "keytypes": ["integer"],
                                "keyvalues": [2]
                        }
                }
                ,{
                        "kind": "update",
                        "schema": "public",
                        "table": "temp",
                        "columnnames": ["id", "val"],
                        "columntypes": ["integer", "text"],
                        "columnvalues": [1, "updated value"],
                        "oldkeys": {
                                "keynames": ["id"],
                                "keytypes": ["integer"],
                                "keyvalues": [1]
                        }
                }
        ]
    }
    ```


- Delete changes (one row):
    ```json 
    {
        "change": [
                {
                        "kind": "delete",
                        "schema": "public",
                        "table": "temp",
                        "oldkeys": {
                                "keynames": ["id"],
                                "keytypes": ["integer"],
                                "keyvalues": [51]
                        }
                }
        ]
    }
    ```



## PostgreSQL Driver

The example is based on a fork from [`postgres` pacakge](https://github.com/osaxma/postgresql-dart) using the `replication` branch. 

The changes wasn't yet proposed to the upstream package as it introduces an entirely new protocol (i.e. Streaming Replication Protocol) to the existing Extended Query Protocol. Once the fork is polished and the api is finalized, the changes will be proposed to the original package. No promises tho.

Important Note: this is just an example and the fork is not ready for production unless you know what you're doing on the PostgreSQL side. 


## Credits
The idea was heavily drawn from the first repos packages and made possible by the third: 
- [PostgreSQL logical replication library for Go - pglogrepl](https://github.com/jackc/pglogrepl)
- [Supabase Realtime](https://github.com/supabase/realtime)
- [postgresql-dart](https://github.com/isoos/postgresql-dart) 

## Further Readings

- [Frontend Backend Protocol](https://www.postgresql.org/docs/current/protocol.html) -- the chapter covering both Replication and Extended Query Protocols. 
- [Streaming Replication Protocol](https://www.postgresql.org/docs/current/protocol-replication.html)
- [Logical Replication Message Formats](https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html)
- [Protocol Message Format](https://www.postgresql.org/docs/current/protocol-message-formats.html)