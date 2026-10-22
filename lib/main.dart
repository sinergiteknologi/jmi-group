import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/app_database.dart';
import 'core/storage/session_store.dart';
import 'data/repositories/erp_repository.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
  await initializeDateFormatting('id_ID');

  final store = SessionStore();
  final db = AppDatabase();
  final repository = ErpRepository(api: ApiClient(), store: store, db: db);
  final state = AppState(repository: repository, store: store, db: db);
  await state.bootstrap();

  runApp(ChangeNotifierProvider.value(value: state, child: const VenusApp()));
}
