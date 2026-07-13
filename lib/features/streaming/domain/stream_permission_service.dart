/// Validates who may start a live stream for a match.
///
/// Any signed-in CrickFlow account may go live on any match.
/// Guests (no account) cannot.
class StreamPermissionService {
  const StreamPermissionService();

  bool canStartStream({required String? userId}) {
    return userId != null && userId.isNotEmpty;
  }
}
