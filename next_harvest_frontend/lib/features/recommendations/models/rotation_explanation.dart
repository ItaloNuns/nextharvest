class RotationExplanation {
  RotationExplanation({
    required this.whySuggested,
    required List<String> supportingEvidence,
    required List<String> expectedBenefits,
    required List<String> informationGapsAndUncertainty,
    required List<String> risksRequiringLocalReview,
  }) : supportingEvidence = List.unmodifiable(supportingEvidence),
       expectedBenefits = List.unmodifiable(expectedBenefits),
       informationGapsAndUncertainty = List.unmodifiable(
         informationGapsAndUncertainty,
       ),
       risksRequiringLocalReview = List.unmodifiable(risksRequiringLocalReview);

  factory RotationExplanation.fromJson(Map<String, dynamic> json) =>
      RotationExplanation(
        whySuggested: json['why_suggested'] as String,
        supportingEvidence: (json['supporting_evidence'] as List)
            .cast<String>(),
        expectedBenefits: (json['expected_benefits'] as List).cast<String>(),
        informationGapsAndUncertainty:
            (json['information_gaps_and_uncertainty'] as List).cast<String>(),
        risksRequiringLocalReview:
            (json['risks_requiring_local_review'] as List).cast<String>(),
      );

  final String whySuggested;
  final List<String> supportingEvidence;
  final List<String> expectedBenefits;
  final List<String> informationGapsAndUncertainty;
  final List<String> risksRequiringLocalReview;
}
