import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_exceptions.dart';
import 'package:louemoi/features/profile/data/agent_profile_repository.dart';
import 'package:louemoi/features/profile/models/agent_profile.dart';

/// Décision métier (mission de finalisation) : Agent → demande → EN_ATTENTE
/// → administrateur → approuvée/refusée. Un agent ne peut jamais
/// s'auto-certifier — is_verified reste toujours false après une simple
/// demande, quel que soit le nombre de tentatives.
void main() {
  group('CertificationStatus.fromString', () {
    test('parses every known backend value', () {
      expect(CertificationStatus.fromString('non_demandee'), CertificationStatus.nonDemandee);
      expect(CertificationStatus.fromString('en_attente'), CertificationStatus.enAttente);
      expect(CertificationStatus.fromString('approuvee'), CertificationStatus.approuvee);
      expect(CertificationStatus.fromString('refusee'), CertificationStatus.refusee);
    });

    test('falls back to nonDemandee for null/unknown values', () {
      expect(CertificationStatus.fromString(null), CertificationStatus.nonDemandee);
      expect(CertificationStatus.fromString('quelquechose'), CertificationStatus.nonDemandee);
    });
  });

  group('AgentProfile.fromJson', () {
    test('parses certification_status alongside is_verified', () {
      final profile = AgentProfile.fromJson({
        'agency_name': 'ABC',
        'whatsapp': '',
        'description': '',
        'is_verified': false,
        'certification_status': 'en_attente',
        'rating': 0,
      });
      expect(profile.certificationStatus, CertificationStatus.enAttente);
      expect(profile.isVerified, isFalse);
    });

    test('defaults to nonDemandee when the key is absent', () {
      final profile = AgentProfile.fromJson({
        'agency_name': '',
        'whatsapp': '',
        'description': '',
        'is_verified': false,
        'rating': 0,
      });
      expect(profile.certificationStatus, CertificationStatus.nonDemandee);
    });
  });

  group('MockAgentProfileRepository.requestCertification', () {
    test('first request succeeds and moves to enAttente, never auto-verifies', () async {
      final repository = MockAgentProfileRepository();
      final profile = await repository.requestCertification();
      expect(profile.certificationStatus, CertificationStatus.enAttente);
      expect(profile.isVerified, isFalse);
    });

    test('a second request while pending is rejected', () async {
      final repository = MockAgentProfileRepository();
      await repository.requestCertification();
      expect(
        () => repository.requestCertification(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
