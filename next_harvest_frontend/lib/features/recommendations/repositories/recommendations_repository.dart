import '../models/recommendation_request.dart';
import '../models/rotation_recommendation.dart';

abstract class RecommendationsRepository {
  Future<RotationRecommendation> simulate(RecommendationRequest request);
}
