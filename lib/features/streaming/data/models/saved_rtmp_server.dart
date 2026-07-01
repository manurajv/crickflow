import 'package:equatable/equatable.dart';

class SavedRtmpServer extends Equatable {
  const SavedRtmpServer({
    required this.id,
    required this.name,
    required this.rtmpUrl,
    this.streamKey = '',
  });

  final String id;
  final String name;
  final String rtmpUrl;
  final String streamKey;

  factory SavedRtmpServer.fromMap(Map<String, dynamic> map) {
    return SavedRtmpServer(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      rtmpUrl: map['rtmpUrl'] as String? ?? '',
      streamKey: map['streamKey'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'rtmpUrl': rtmpUrl,
        'streamKey': streamKey,
      };

  @override
  List<Object?> get props => [id, name, rtmpUrl];
}
