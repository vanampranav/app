import 'package:flutter_test/flutter_test.dart';
import 'package:elefit_app/utils/app_error_mapper.dart';

void main() {
  group('AppErrorMapper', () {
    test('surfaces a plain domain-rule message instead of "something went wrong"',
        () {
      final e = AppErrorMapper.map(
          Exception('You have reached the maximum of 3 resubmissions.'));
      expect(e.title, isNot('Something went wrong'));
      expect(e.message, contains('maximum of 3 resubmissions'));
      // The "Exception:" prefix must be stripped.
      expect(e.message, isNot(contains('Exception:')));
    });

    test('shows the real weekly-checkin rule text', () {
      final e =
          AppErrorMapper.map(Exception('Weekly check-ins open after your first week.'));
      expect(e.message, 'Weekly check-ins open after your first week.');
    });

    test('maps a permission error to Access Denied', () {
      final e = AppErrorMapper.map(Exception('permission-denied: missing rule'));
      expect(e.title, 'Access Denied');
      expect(e.technicalCode, 'PERMISSION_DENIED');
    });

    test('keeps the generic copy for a clearly technical error', () {
      final e = AppErrorMapper.map(
          Exception("type 'Null' is not a subtype of type 'String'"));
      expect(e.title, 'Something went wrong');
    });

    test('does not leak a raw FlutterFire "[plugin/code]" string', () {
      final e = AppErrorMapper.map(
          Exception('[cloud_firestore/aborted] The operation was aborted.'));
      expect(e.title, 'Something went wrong');
      expect(e.message, isNot(contains('cloud_firestore')));
    });

    test('maps a storage "unauthorized" error to Access Denied', () {
      final e = AppErrorMapper.map(
          Exception('[firebase_storage/unauthorized] User is not authorized.'));
      expect(e.title, 'Access Denied');
    });

    test('maps quota / resource-exhausted to Server Busy', () {
      final e = AppErrorMapper.map(
          Exception('[cloud_firestore/resource-exhausted] Quota exceeded.'));
      expect(e.title, 'Server Busy');
    });
  });
}
