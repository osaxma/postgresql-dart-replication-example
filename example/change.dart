import 'package:postgres/postgres.dart';

/// Run this file after running `listen_v3.dart`
///
/// This function will modify the database to mimic changes
void main() async {
  print('connecting to db');
  final conn = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'postgres',
      username: 'postgres',
      password: 'postgres',
    ),
    sessionSettings: SessionSettings(
      sslMode: SslMode.disable
    )
  );

  // create table
  await conn.execute('''
create table if not exists temp (
    id int GENERATED ALWAYS AS IDENTITY, 
    val text,
    PRIMARY KEY (id)
    );
''');

  await wait(2);
  print('inserting values');
  await conn.execute('''
insert into temp (val) values ('value1'), ('value2'), ('value3');
''');

  await wait(2);
  print('updating values');
  await conn.execute('''
update temp set val = 'value' where id in (select id from temp limit 2);
''');

  await wait(2);
  print('deleting values');
  await conn.execute('''
delete from temp where id in (select id from temp limit 2);
''');

  await wait(2);
  print('truncating table');
  // this may not show a change when using `wal2json` due to format version but it'd show using `pgoutput`
  await conn.execute('''
truncate table temp;
''');

  print('closing connection');
  await conn.close();
}

Future<void> wait(int seconds) async => await Future.delayed(Duration(seconds: seconds));
