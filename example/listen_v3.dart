import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres_v3_experimental.dart';
import 'package:postgres/postgres.dart';
import 'package:postgres/messages.dart';

// You need to add this package to pubspec.yaml
import 'package:stream_channel/stream_channel.dart';

/// An exposed "Channel" that provides a sink and a stream that can be used to send and receive server messages.
class ExposedChannel implements StreamChannelTransformer<BaseMessage, BaseMessage> {
  final Completer<StreamChannel<BaseMessage>> _completer = Completer();

  /// Use this sink to send messages to the server
  Future<StreamSink> get sink async => (await _completer.future).sink;

  /// Use this stream to listen to messages from the server
  Future<Stream> get stream async => (await _completer.future).stream;

  @override
  StreamChannel<BaseMessage> bind(StreamChannel<BaseMessage> channel) {
    final broadcast = channel.changeStream((stream) => stream.asBroadcastStream());
    _completer.complete(broadcast);
    return broadcast;
  }
}

void main(List<String> arguments) async {
  // let PgConnection bind our channel so we can use it to send/receive server messages.
  final channel = ExposedChannel();
  // create the replication connection
  final conn = await PgConnection.open(
    PgEndpoint(
      host: 'localhost',
      port: 5432,
      database: 'postgres',
      username: 'postgres',
      password: 'postgres',
    ),
    sessionSettings: PgSessionSettings(
      // Specify the type of connection for Streaming Replication
      replicationMode: ReplicationMode.logical,
      // In Streaming Replication connection, only the simple query protocol can be used.
      queryMode: QueryMode.simple,
      // pass our channel for binding
      transformer: channel,
    ),
  );

  // Grab the stream and sink from the exposed channel after it has been binded by PgConnection
  final stream = await channel.stream;
  final sink = await channel.sink;

  /* -------------------------------------------------------------------------- */
  /*                             listen to messages                             */
  /* -------------------------------------------------------------------------- */
  // this will handle keep alive messages and print any replication messages
  late LSN clientXLogPos;
  final messagesSub = stream.listen((msg) {
    /// Handle Keep Alive Messages to avoid losing connection
    if (msg is XLogDataMessage) {
      clientXLogPos = msg.walStart + msg.walDataLength;
    } else if (msg is PrimaryKeepAliveMessage) {
      if (msg.mustReply) {
        final statusUpdate = StandbyStatusUpdateMessage(walWritePosition: clientXLogPos, mustReply: false);
        final copyDataMessage = CopyDataMessage(statusUpdate.asBytes(encoding: utf8));
        sink.add(copyDataMessage);
      }
    }

    if (msg is XLogDataMessage) {
      print('received a change in database:');
      final data = msg.data.toString();
      // print the data with an indent 
      print('\t${data.replaceAll('\n', '\n\t')}');
      print('\t\t-------------------------------------\n');
    } else if (msg is ErrorResponseMessage) {
      print('errr ${msg.fields.map((e) => e.text).join('. ')}');
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
  await conn.execute('DROP PUBLICATION IF EXISTS $publicationName;');
  await conn.execute('CREATE PUBLICATION $publicationName FOR ALL TABLES;');

  /* -------------------------------------------------------------------------- */
  /*                           create replication slot                          */
  /* -------------------------------------------------------------------------- */
  // read more here: https://www.postgresql.org/docs/current/protocol-replication.html
  await dropReplicationSlotIfExists(conn, replicationSlotName);
  await conn.execute('CREATE_REPLICATION_SLOT $replicationSlotName LOGICAL wal2json NOEXPORT_SNAPSHOT');

  // Identify the system to get the `xlogpos` which is the current WAL flush location.
  // Useful to get a known location in the write-ahead log where streaming can start.
  final sysInfo = (await conn.execute('IDENTIFY_SYSTEM;'));

  // the sysinfo result comes as one row in the following schema as an example:
  //  {systemid: 7284963011864342566, timeline: 1, xlogpos: 0/172A8F8, dbname: postgres}
  // so `xlogpos` will be in the first row and the third column (hence [0][2])
  final xlogpos = sysInfo[0][2] as String;
  clientXLogPos = LSN.fromString(xlogpos);
  // final timeline = sysInfo['timeline'] as String; // can be used for physical replication

  /* -------------------------------------------------------------------------- */
  /*                           start replication slot                           */
  /* -------------------------------------------------------------------------- */
  // read more here: https://www.postgresql.org/docs/current/protocol-replication.html

  // choose a replication plugin decoding
  final replicationOutput = 'wal2json'; // another option is 'pgoutput'

  final String stmt;
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
  await conn.execute(stmt).timeout(Duration(seconds: 3600)).catchError((e) {
    return e;
  });
}

/* -------------------------------------------------------------------------- */
/*                              helper functions                              */
/* -------------------------------------------------------------------------- */

Future<dynamic> dropReplicationSlotIfExists(PgConnection conn, String slotname) async {
  // using either 'DROP_REPLICATION_SLOT $replicationSlotName' or select pg_drop_replication_slot('$replicationSlotName')
  // will throw an error if the replication slot does not exist
  // see other replication mgmt functions here:
  // https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-REPLICATION
  return await conn.execute(
    "select pg_drop_replication_slot('$slotname') from pg_replication_slots where slot_name = '$slotname';",
  );
}