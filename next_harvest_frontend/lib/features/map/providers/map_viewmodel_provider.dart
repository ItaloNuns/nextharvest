import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/map_state.dart';
import '../viewmodel/map_viewmodel.dart';

final mapViewModelProvider = NotifierProvider<MapViewModel, MapState>(
  MapViewModel.new,
);
