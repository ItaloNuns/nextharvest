import '../models/satellite_map_layer.dart';
import '../models/map_reference_layer.dart';

abstract class MapRepository {
  MapReferenceLayer getReferenceLayer();
  Future<SatelliteMapLayer> getLayer({MapSource source = MapSource.sentinel});
}
