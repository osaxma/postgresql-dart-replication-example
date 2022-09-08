// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:postgres/messages.dart';

void main(List<String> arguments) async {
  // choose a replication mode
  final replicationMode = ReplicationMode.logical;
  // choose a replication plugin decoding
  final replicationOutput = LogicalDecodingPlugin.wal2json; // try LogicalDecodingPlugin.pgoutput
  final conn = PostgreSQLConnection(
    'localhost',
    5432,
    'postgres',
    username: 'postgres',
    password: 'postgres',
    replicationMode: replicationMode,
    logicalDecodingPlugin: replicationOutput,
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
        final copyDataMessage = CopyDataMessage(statusUpdate.asBytes());
        conn.socket!.add(copyDataMessage.asBytes());
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
  await conn.executeSimple('DROP PUBLICATION IF EXISTS $publicationName;');
  await conn.executeSimple('CREATE PUBLICATION $publicationName FOR ALL TABLES;');

  /* -------------------------------------------------------------------------- */
  /*                           create replication slot                          */
  /* -------------------------------------------------------------------------- */
  // read more here: https://www.postgresql.org/docs/current/protocol-replication.html
  await dropReplicationSlotIfExists(conn, replicationSlotName);
  await conn
      .execute('CREATE_REPLICATION_SLOT $replicationSlotName LOGICAL ${replicationOutput.name} NOEXPORT_SNAPSHOT');

  // Identify the system to get the `xlogpos` which is the current WAL flush location.
  // Useful to get a known location in the write-ahead log where streaming can start.
  final sysInfo = ((await conn.executeSimple('IDENTIFY_SYSTEM;')) as PostgreSQLResult).first.toColumnMap();
  final xlogpos = sysInfo['xlogpos'] as String;
  clientXLogPos = LSN.fromString(xlogpos);
  // final timeline = sysInfo['timeline'] as String; // can be used for physical replication

  /* -------------------------------------------------------------------------- */
  /*                           start replication slot                           */
  /* -------------------------------------------------------------------------- */
  // read more here: https://www.postgresql.org/docs/current/protocol-replication.html
  late final String stmt;
  switch (replicationOutput) {
    case LogicalDecodingPlugin.pgoutput:
      stmt = "START_REPLICATION SLOT $replicationSlotName LOGICAL $xlogpos"
          "(proto_version '1', publication_names '$publicationName')";
      break;
    case LogicalDecodingPlugin.wal2json:
      stmt = "START_REPLICATION SLOT $replicationSlotName LOGICAL $xlogpos"
          "(\"pretty-print\" 'true')";
      break;
  }

  /// Run the start replication statement
  /// This future won't complete unless the server drops the connection
  /// or an error occurs
  /// or it times out
  await conn.executeSimple(stmt, timeoutInSeconds: 3600).catchError((e) {
    return null;
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
  return await conn.executeSimple(
    "select pg_drop_replication_slot('$slotname') from pg_replication_slots where slot_name = '$slotname';",
  );
}
