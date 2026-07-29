import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

/// Whether [error] is a genuine network-connectivity failure rather than a
/// server- or data-level fault.
///
/// Only a verified connectivity failure earns the "you're offline" framing in
/// the UI. A malformed response, an auth-state error, or a signature-verify
/// throw is a real fault that the offline copy would hide — the product's
/// warn-only-when-verified rule means those must surface as themselves, never
/// as a misleading "you're offline" message. Shared by every screen that
/// distinguishes the two so they classify identically.
bool isConnectivityError(Object error) {
  if (error is SocketException) return true;
  if (error is DioException) {
    if (error.error is SocketException) return true;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }
  return false;
}
