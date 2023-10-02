import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres_v3_experimental.dart';
import 'package:postgres/postgres.dart';
import 'package:postgres/messages.dart';

// You need to add these two packages to pubspec.yaml
import 'package:stream_channel/stream_channel.dart';
import 'package:async/async.dart';

/// A "Channel" that can send and receive messages to and from the Server.
class ServerChannel {
  final _controller = StreamController<ServerMessage>.broadcast();

  Stream<ServerMessage> get messages => _controller.stream;

  EventSink<BaseMessage>? _cachedSink;

  void addMessage(BaseMessage message) {
    if (_cachedSink == null) {
      throw Exception('Cannot send message because sink is not available');
    }
    _cachedSink!.add(message);
  }

  late final transformer = StreamChannelTransformer<BaseMessage, BaseMessage>(
    // to listen to server messages
    StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        if (!_controller.isClosed) {
          _controller.add(data as ServerMessage);
        }
        // let the message continue its journey
        sink.add(data);
      },
    ),
    // this is intended to listen to client messages
    // but we capture the sink and cache it so we can send messages
    // to the server when needed.
    StreamSinkTransformer.fromHandlers(
      handleData: (data, sink) {
        if (_cachedSink != sink) {
          _cachedSink = sink;
        }
        // let the message continue its journey
        sink.add(data);
      },
      handleDone: (sink) {
        _cachedSink = null;
        sink.close();
      },
      handleError: (_, __, sink) {
        _cachedSink = null;
        sink.close();
        // handle the error ...
      },
    ),
  );

  Future<void> close() async {
    _cachedSink = null;
    await _controller.close();
  }
}

final serverChannel = ServerChannel();

void main(List<String> arguments) async {
  final conn = await PgConnection.open(
    PgEndpoint(
      host: 'localhost',
      port: 5432,
      database: 'postgres',
      username: 'postgres',
      password: 'postgres',
    ),
    sessionSettings: PgSessionSettings(
        replicationMode: ReplicationMode.logical,
        queryMode: QueryMode.simple,
        onBadSslCertificate: (cert) => true,
        transformer: serverChannel.transformer,
        encoding: utf8),
  );

  /* -------------------------------------------------------------------------- */
  /*                             listen to messages                             */
  /* -------------------------------------------------------------------------- */
  // this will handle keep alive messages and print any replication messages
  late LSN clientXLogPos;
  final messagesSub = serverChannel.messages.listen((msg) {
    /// Handle Keep Alive Messages to avoid losing connection
    if (msg is XLogDataMessage) {
      clientXLogPos = msg.walStart + msg.walDataLength;
    } else if (msg is PrimaryKeepAliveMessage) {
      if (msg.mustReply) {
        final statusUpdate = StandbyStatusUpdateMessage(walWritePosition: clientXLogPos, mustReply: false);
        final copyDataMessage = CopyDataMessage(statusUpdate.asBytes(encoding: utf8));
        serverChannel.addMessage(copyDataMessage);
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
    await serverChannel.close();
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