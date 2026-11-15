import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/area_draft_state.dart';
import '../viewmodel/area_draft_viewmodel.dart';

final areaDraftViewModelProvider =
    NotifierProvider<AreaDraftViewModel, AreaDraftState>(
      AreaDraftViewModel.new,
    );
