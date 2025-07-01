import 'xyz.dart';

enum DownloadStatusEnum { downloading, completed, error }

class DownloadStatus {
  final DownloadStatusEnum status;
  final XYZ? xyz;
  final Object? error;
  final StackTrace? stackTrace;

  const DownloadStatus({
    required this.status,
    this.xyz,
    this.error,
    this.stackTrace,
  });

  factory DownloadStatus.completed() =>
      const DownloadStatus(status: DownloadStatusEnum.completed);

  factory DownloadStatus.error(Object error, StackTrace stackTrace, XYZ xyz) =>
      DownloadStatus(
          status: DownloadStatusEnum.error,
          error: error,
          xyz: xyz,
          stackTrace: stackTrace);

  factory DownloadStatus.downloading(XYZ xyz) =>
      DownloadStatus(status: DownloadStatusEnum.downloading, xyz: xyz);
}
