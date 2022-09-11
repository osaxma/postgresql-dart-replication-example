# Listening to Logical Replication Example


## Prerequisites

- Dart 
- Docker

## Set up the database 
1. Clone the repo this repo:
    ```
    git clone https://github.com/osaxma/postgresql-dart-replication-example.git
    ```
2. Run `dart pub get`. 

3. Run `cd postgresql-dart-replication-example/examples`

4. Build a docker image for PostgreSQL with wal2json (this will take few minutes to download images and whatnot):
    ```
    docker build -t replication_example_image . 
    ```
    must be in `examples` when running the command above)

5. run the container (the configs starting with `-c` are necessary for replication to work)
    ```
    docker run -d -p 5432:5432 --name replication_example_container replication_example_image -c wal_level=logical -c max_replication_slots=5 -c max_wal_senders=5
    ```


## Run the examples

Now that the database is ready, open two terminals and run the following:

- In one terminal:
    ```sh
    dart run listen.dart
    ```

- In another terminal:
    ```sh
    dart run change.dart
    ```


Over the following few seconds, the first terminal should output the following:

- `listen.dart` output
```
press ctrl + c to exit at any time
received a change in database:
{
        "change": [
                {
                        "kind": "insert",
                        "schema": "public",
                        "table": "temp",
                        "columnnames": ["id", "val"],
                        "columntypes": ["integer", "text"],
                        "columnvalues": [19, "value1"]
                }
                ,{
                        "kind": "insert",
                        "schema": "public",
                        "table": "temp",
                        "columnnames": ["id", "val"],
                        "columntypes": ["integer", "text"],
                        "columnvalues": [20, "value2"]
                }
                ,{
                        "kind": "insert",
                        "schema": "public",
                        "table": "temp",
                        "columnnames": ["id", "val"],
                        "columntypes": ["integer", "text"],
                        "columnvalues": [21, "value3"]
                }
        ]
}
-------------------------------------

received a change in database:
{
        "change": [
                {
                        "kind": "update",
                        "schema": "public",
                        "table": "temp",
                        "columnnames": ["id", "val"],
                        "columntypes": ["integer", "text"],
                        "columnvalues": [19, "value"],
                        "oldkeys": {
                                "keynames": ["id"],
                                "keytypes": ["integer"],
                                "keyvalues": [19]
                        }
                }
                ,{
                        "kind": "update",
                        "schema": "public",
                        "table": "temp",
                        "columnnames": ["id", "val"],
                        "columntypes": ["integer", "text"],
                        "columnvalues": [20, "value"],
                        "oldkeys": {
                                "keynames": ["id"],
                                "keytypes": ["integer"],
                                "keyvalues": [20]
                        }
                }
        ]
}
-------------------------------------

received a change in database:
{
        "change": [
                {
                        "kind": "delete",
                        "schema": "public",
                        "table": "temp",
                        "oldkeys": {
                                "keynames": ["id"],
                                "keytypes": ["integer"],
                                "keyvalues": [19]
                        }
                }
                ,{
                        "kind": "delete",
                        "schema": "public",
                        "table": "temp",
                        "oldkeys": {
                                "keynames": ["id"],
                                "keytypes": ["integer"],
                                "keyvalues": [21]
                        }
                }
        ]
}
-------------------------------------

received a change in database:
{
        "change": [
        ]
}
-------------------------------------
```

- `change.dart` output 
```
connecting to db
inserting values
updating values
deleting values
truncating table
closing connection
```


### Extra

- `listen.dart` output when using `pgoutput`:
    - change the `replicationOutput` to `LogicalDecodingPlugin.pgoutput` in `listen.dart` 
    - re-run both `listen.dart` then `change.dart` 
<details>
  <summary>Click To Expand</summary>

```
press ctrl + c to exit at any time
received a change in database:
BeginMessage(finalLSN: 0/1731A38, commitTime: 2022-09-08 20:54:57.589907Z, xid: 765)
-------------------------------------

received a change in database:
RelationMessage(relationID: 16387, nameSpace: public, relationName: temp, replicaIdentity: 100, columnNum: 2, columns: [RelationMessageColumn(flags: 1, name: id, dataType: 23, typeModifier: 4294967295), RelationMessageColumn(flags: 0, name: val, dataType: 25, typeModifier: 4294967295)])
-------------------------------------

received a change in database:
InsertMessage(relationID: 16387, tuple: TupleData(columnNum: 2, columns: [TupleDataColumn(dataType: 116, length: 2, data: 16), TupleDataColumn(dataType: 116, length: 6, data: value1)]))
-------------------------------------

received a change in database:
InsertMessage(relationID: 16387, tuple: TupleData(columnNum: 2, columns: [TupleDataColumn(dataType: 116, length: 2, data: 17), TupleDataColumn(dataType: 116, length: 6, data: value2)]))
-------------------------------------

received a change in database:
InsertMessage(relationID: 16387, tuple: TupleData(columnNum: 2, columns: [TupleDataColumn(dataType: 116, length: 2, data: 18), TupleDataColumn(dataType: 116, length: 6, data: value3)]))
-------------------------------------

received a change in database:
CommitMessage(flags: 0, commitLSN: 0/1731A38, transactionEndLSN: 0/1731A68, commitTime: 2022-09-08 20:54:57.589907Z)
-------------------------------------

received a change in database:
BeginMessage(finalLSN: 0/1731B08, commitTime: 2022-09-08 20:54:59.601568Z, xid: 766)
-------------------------------------

received a change in database:
UpdateMessage(relationID: 16387, oldTupleType: null, oldTuple: null, newTuple: TupleData(columnNum: 2, columns: [TupleDataColumn(dataType: 116, length: 2, data: 16), TupleDataColumn(dataType: 116, length: 5, data: value)]))
-------------------------------------

received a change in database:
UpdateMessage(relationID: 16387, oldTupleType: null, oldTuple: null, newTuple: TupleData(columnNum: 2, columns: [TupleDataColumn(dataType: 116, length: 2, data: 17), TupleDataColumn(dataType: 116, length: 5, data: value)]))
-------------------------------------

received a change in database:
CommitMessage(flags: 0, commitLSN: 0/1731B08, transactionEndLSN: 0/1731B38, commitTime: 2022-09-08 20:54:59.601568Z)
-------------------------------------

received a change in database:
BeginMessage(finalLSN: 0/1731BB8, commitTime: 2022-09-08 20:55:01.609710Z, xid: 767)
-------------------------------------

received a change in database:
DeleteMessage(relationID: 16387, oldTupleType: DeleteMessageTuple.keyType, oldTuple: TupleData(columnNum: 2, columns: [TupleDataColumn(dataType: 116, length: 2, data: 16), TupleDataColumn(dataType: 110, length: 0, data: )]))
-------------------------------------

received a change in database:
DeleteMessage(relationID: 16387, oldTupleType: DeleteMessageTuple.keyType, oldTuple: TupleData(columnNum: 2, columns: [TupleDataColumn(dataType: 116, length: 2, data: 18), TupleDataColumn(dataType: 110, length: 0, data: )]))
-------------------------------------

received a change in database:
CommitMessage(flags: 0, commitLSN: 0/1731BB8, transactionEndLSN: 0/1731BE8, commitTime: 2022-09-08 20:55:01.609710Z)
-------------------------------------

received a change in database:
BeginMessage(finalLSN: 0/1732768, commitTime: 2022-09-08 20:55:03.623966Z, xid: 768)
-------------------------------------

received a change in database:
RelationMessage(relationID: 16387, nameSpace: public, relationName: temp, replicaIdentity: 100, columnNum: 2, columns: [RelationMessageColumn(flags: 1, name: id, dataType: 23, typeModifier: 4294967295), RelationMessageColumn(flags: 0, name: val, dataType: 25, typeModifier: 4294967295)])
-------------------------------------

received a change in database:
TruncateMessage(relationNum: 1, option: TruncateOptions.none, relationIds: [16387])
-------------------------------------

received a change in database:
CommitMessage(flags: 0, commitLSN: 0/1732768, transactionEndLSN: 0/17328D8, commitTime: 2022-09-08 20:55:03.623966Z)
-------------------------------------
```
</details>


## Notes
Remember this is just an example. There's more to managing replication slots and its configuration. Be cautious when using this on a production database to avoid unintended consequences (e.g., out of memory errors caused by replication slots and such). 
