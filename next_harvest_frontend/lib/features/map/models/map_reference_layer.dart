/// Transparent administrative reference layer, independent of the background imagery.
class MapReferenceLayer {
  const MapReferenceLayer({
    required this.id,
    required this.urlTemplate,
    required this.attribution,
    required this.maxNativeZoom,
  });

  final String id;
  final String urlTemplate;
  final String attribution;
  final int maxNativeZoom;
}
