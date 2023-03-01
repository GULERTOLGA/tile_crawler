part of tile_crawler;

enum DownloadStatusEnum { downloading, completed, error }

class DownloadStatus {
  final DownloadStatusEnum status;
  final XYZ? xyz;
  final Object? error;

  DownloadStatus({required this.status, this.xyz, this.error});

  factory DownloadStatus.completed() =>
      DownloadStatus(status: DownloadStatusEnum.completed);
  factory DownloadStatus.error(String error) =>
      DownloadStatus(status: DownloadStatusEnum.error, error: error);
  factory DownloadStatus.downloading(XYZ xyz) =>
      DownloadStatus(status: DownloadStatusEnum.downloading, xyz: xyz);
}
