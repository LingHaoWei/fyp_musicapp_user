import 'package:flutter/material.dart';
import 'package:flutter_acrcloud/flutter_acrcloud.dart';

class VoiceRecognitionPage extends StatefulWidget {
  const VoiceRecognitionPage({super.key});

  @override
  VoiceRecognitionPageState createState() => VoiceRecognitionPageState();
}

class VoiceRecognitionPageState extends State<VoiceRecognitionPage> {
  bool _isRecognizing = false;
  String _status = 'Tap the microphone to start';
  final apiKey = '91a33e913303861e440f8e32878f6750';
  final apiSecret = 'aMACc6bqy1ASyY2bRvqTg5L7ThDBJxjRSflcIkCt';
  final host = 'identify-ap-southeast-1.acrcloud.com';

  @override
  void initState() {
    super.initState();
    ACRCloud.setUp(ACRCloudConfig(apiKey, apiSecret, host));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recognition'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isRecognizing
                  ? null
                  : () async {
                      setState(() {
                        _isRecognizing = true;
                        _status = 'Listening...';
                      });

                      try {
                        final session = ACRCloud.startSession();

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF202020),
                            title: const Text('Listening...'),
                            content: StreamBuilder(
                              stream: session.volumeStream,
                              initialData: 0,
                              builder: (_, snapshot) => const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Play, Sing or Hum a song'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: session.cancel,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        );

                        final result = await session.result;
                        if (!mounted) return;
                        Navigator.pop(context); // Close the listening dialog

                        if (result == null) {
                          setState(() {
                            _status = 'Tap to try again';
                            _isRecognizing = false;
                          });
                          return;
                        }

                        if (result.metadata == null ||
                            result.metadata!.music.isEmpty) {
                          setState(() {
                            _status = 'No match found. Try again?';
                            _isRecognizing = false;
                          });
                          return;
                        }

                        final music = result.metadata!.music.first;
                        // Return both title and artist for better search results
                        final searchQuery = '${music.title}';
                        Navigator.pop(context, searchQuery);
                      } catch (e) {
                        setState(() {
                          _status = 'Recognition failed. Try again?';
                          _isRecognizing = false;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to recognize music'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff292929),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff202020).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isRecognizing
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 40,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
