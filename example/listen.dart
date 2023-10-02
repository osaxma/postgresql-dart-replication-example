import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:postgres/messages.dart';

void main(List<String> arguments) async {
  // choose a replication mode
  final replicationMode = ReplicationMode.logical;
  // choose a replication plugin decoding
  final replicationOutput = 'wal2json'; // another option is 'pgoutput'
  final conn = PostgreSQLConnection(
    'localhost',
    5432,
    'postgres',
    username: 'postgres',
    password: 'postgres',
    replicationMode: replicationMode,
    encoding: utf8,
  );
  await conn.open();

  /* -------------------------------------------------------------------------- */
  /*                             listen to messages                             */
  /* -------------------------------------------------------------------------- */
  // this will handle keep alive messages and print any replication messages
  late LSN clientXLogPos;
  final messagesSub = conn.messages.listen((msg) {
    /// Handle Keep Alive Messages to avoid losing connection
    if (msg is XLogDataMessage) {
      clientXLogPos = msg.walStart + msg.walDataLength;
    } else if (msg is PrimaryKeepAliveMessage) {
      if (msg.mustReply) {
        final statusUpdate = StandbyStatusUpdateMessage(walWritePosition: clientXLogPos, mustReply: false);
        // in older versions, `asBytes` didn't require encoding to be passed so remove it if it gives u an error
        final copyDataMessage = CopyDataMessage(statusUpdate.asBytes(encoding: utf8)); 
        conn.addMessage(copyDataMessage);
      }
    }

    if (msg is ErrorResponseMessage) {
      print('errr ${msg.fields.map((e) => e.text).join('. ')}');
    } else {
      if (msg is XLogDataMessage) {
        print('received a change in database:');
        print(msg.data);
        print('-------------------------------------\n');
      }
    }
  });

  /* -------------------------------------------------------------------------- */
  /*                             listen to ctrl + c                             */
  /* -------------------------------------------------------------------------- */
  // capture the `ctrl + c` to close connection and whatnot
  print('press ctrl + c to exit at any time');
  late StreamSubscription<ProcessSignal> sigintSub;
  sigintSub = ProcessSignal.sigint.watch().listen((_) async {
    print('\nExiting...');
    sigintSub.cancel();
    await messagesSub.cancel();
    await conn.close();
  });

  /* -------------------------------------------------------------------------- */
  /*                             create publication                             */
  /* -------------------------------------------------------------------------- */
  // the name of the publication
  final publicationName = 'a_test_publication';
  // the name of the replication slot
  final replicationSlotName = 'a_test_slot';

  // create the publication and drop it if it exists
  await conn.query('DROP PUBLICATION IF EXISTS $publicationName;', useSimpleQueryProtocol: true);
  await conn.query('CREATE PUBLICATION $publicationName FOR ALL TABLES;', useSimpleQueryProtocol: true);

  /* -------------------------------------------------------------------------- */
  /*                           create replication slot                          */
  /* -------------------------------------------------------------------------- */
  // read more here: https://www.postgresql.org/docs/current/protocol-replication.html
  await dropReplicationSlotIfExists(conn, replicationSlotName);
  await conn.execute('CREATE_REPLICATION_SLOT $replicationSlotName LOGICAL wal2json NOEXPORT_SNAPSHOT');

  // Identify the system to get the `xlogpos` which is the current WAL flush location.
  // Useful to get a known location in the write-ahead log where streaming can start.
  final sysInfo = (await conn.query('IDENTIFY_SYSTEM;', useSimpleQueryProtocol: true)).first.toColumnMap();
  print(sysInfo);
  final xlogpos = sysInfo['xlogpos'] as String;
  clientXLogPos = LSN.fromString(xlogpos);
  // final timeline = sysInfo['timeline'] as String; // can be used for physical replication

  /* -------------------------------------------------------------------------- */
  /*                           start replication slot                           */
  /* -------------------------------------------------------------------------- */
  // read more here: https://www.postgresql.org/docs/current/protocol-replication.html
  late final String stmt;
  if (replicationOutput == 'wal2json') {
    stmt = "START_REPLICATION SLOT $replicationSlotName LOGICAL $xlogpos"
        "(\"pretty-print\" 'true')";
  } else {
    stmt = "START_REPLICATION SLOT $replicationSlotName LOGICAL $xlogpos"
        "(proto_version '1', publication_names '$publicationName')";
  }

  /// Run the start replication statement
  /// This future won't complete unless the server drops the connection
  /// or an error occurs
  /// or it times out
  await conn.execute(stmt, timeoutInSeconds: 3600).catchError((e) {
    return 0;
  });
}

/* -------------------------------------------------------------------------- */
/*                              helper functions                              */
/* -------------------------------------------------------------------------- */

Future<dynamic> dropReplicationSlotIfExists(PostgreSQLConnection conn, String slotname) async {
  // using either 'DROP_REPLICATION_SLOT $replicationSlotName' or select pg_drop_replication_slot('$replicationSlotName')
  // will throw an error if the replication slot does not exist
  // see other replication mgmt functions here:
  // https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-REPLICATION
  return await conn.query(
    "select pg_drop_replication_slot('$slotname') from pg_replication_slots where slot_name = '$slotname';",
    useSimpleQueryProtocol: true,
  );
}
