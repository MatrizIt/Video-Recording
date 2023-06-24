class CameraInformation {
  final String deviceId;
  final String cameraName;
  const CameraInformation({
    required this.deviceId,
    required this.cameraName,
  });

  factory CameraInformation.fromMap(Map map) {
    return CameraInformation(
      deviceId: map['deviceId'],
      cameraName: map['cameraName'],
    );
  }
}
