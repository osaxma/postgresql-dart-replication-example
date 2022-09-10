# Listening PostgreSQL Logical Replication

This repo contains an example under the [example folder](/example/) for listening to Postgresql Logical Replication using the dart `postgres` package ([pub] | [repo]). This allows listening to changes in PostgreSQL database in the following manner:

[repo]: https://github.com/isoos/postgresql-dart
[pub]: https://pub.dev/packages/postgres

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



## Further Readings
- [Frontend Backend Protocol](https://www.postgresql.org/docs/current/protocol.html) -- the chapter covering both Replication and Extended Query Protocols. 
- [Streaming Replication Protocol](https://www.postgresql.org/docs/current/protocol-replication.html)
- [Logical Replication Message Formats](https://www.postgresql.org/docs/current/protocol-logicalrep-message-formats.html)
- [Protocol Message Format](https://www.postgresql.org/docs/current/protocol-message-formats.html)