#!/usr/bin/env bash
# Adds the project's packages. Versions are chosen by `flutter pub add`, never typed by hand.
set -euo pipefail

cd "$(dirname "$0")/.."

flutter pub add flutter_riverpod riverpod_annotation go_router freezed_annotation json_annotation flutter_blue_plus dio web_socket_channel multicast_dns drift sqlite3 path_provider path flutter_secure_storage cryptography local_auth fl_chart flutter_local_notifications csv pdf share_plus workmanager json_schema intl
flutter pub add --dev build_runner riverpod_generator freezed json_serializable drift_dev mocktail
flutter pub add --dev integration_test --sdk=flutter
