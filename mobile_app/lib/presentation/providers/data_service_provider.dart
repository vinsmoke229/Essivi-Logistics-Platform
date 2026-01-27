import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/data_service.dart';

final dataServiceProvider = Provider<DataService>((ref) {
  return DataService();
});
