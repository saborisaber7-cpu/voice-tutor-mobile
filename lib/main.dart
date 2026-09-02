import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoiceTutorApp());
}

class VoiceTutorApp extends StatelessWidget {
  const VoiceTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Tutor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isLoading = false;
  String _selectedAccent = 'US'; // 'US' or 'UK'
  
  String _userText = '';
  String _aiText = '';
  String _recordedPath = '';

  // آدرس سرور رندر شما
  final String _backendUrl = 'https://voice-tutor-backend-co0k.onrender.com';

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        _recordedPath = '${tempDir.path}/user_audio.m4a';

        const config = RecordConfig(encoder: AudioEncoder.aacLc);
        await _audioRecorder.start(config, path: _recordedPath);
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      _showSnackBar('خطا در شروع ضبط: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isLoading = true;
      });

      if (path != null) {
        await _sendAudioToServer(File(path));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('خطا در توقف ضبط: $e');
    }
  }

  Future<void> _sendAudioToServer(File audioFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendUrl/chat-voice'),
      );

      request.fields['accent'] = _selectedAccent;
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _userText = data['user_text'] ?? '';
          _aiText = data['ai_text'] ?? '';
        });

        String? audioUrl = data['audio_url'];
        if (audioUrl != null && audioUrl.isNotEmpty) {
          if (!audioUrl.startsWith('http')) {
            audioUrl = '$_backendUrl$audioUrl';
          }
          await _audioPlayer.play(UrlSource(audioUrl));
        }
      } else {
        _showSnackBar('خطای سرور: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('خطا در برقراری ارتباط با سرور: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('آموزش مکالمه انگلیسی'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: DropdownButton<String>(
              value: _selectedAccent,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'US', child: Text('🇺🇸 American')),
                DropdownMenuItem(value: 'UK', child: Text('🇬🇧 British')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedAccent = val);
                }
              },
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  if (_userText.isNotEmpty)
                    Card(
                      color: Colors.deepPurple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🗣 You:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_userText, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_aiText.isNotEmpty)
                    Card(
                      color: Colors.grey.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🤖 Tutor:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_aiText, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: GestureDetector(
                onTap: _isLoading
                    ? null
                    : () {
                        if (_isRecording) {
                          _stopRecordingAndSend();
                        } else {
                          _startRecording();
                        }
                      },
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
            Text(
              _isRecording ? 'در حال ضبط... (برای ارسال لمس کنید)' : 'برای صحبت دکمه میکروفون را لمس کنید',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
