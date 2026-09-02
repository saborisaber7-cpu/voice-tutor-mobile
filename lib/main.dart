import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() => runApp(const MaterialApp(
      home: VoiceTutorScreen(),
      debugShowCheckedModeBanner: false,
    ));

class VoiceTutorScreen extends StatefulWidget {
  const VoiceTutorScreen({Key? key}) : super(key: key);

  @override
  State<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends State<VoiceTutorScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _textController = TextEditingController();

  String _selectedAccent = "american";
  String _selectedScenario = "General Chat";
  double _playbackSpeed = 1.0;
  bool _isRecording = false;
  bool _isLoading = false;

  final List<Map<String, String>> _messages = [];

  // آدرس سرور رندر اختصاصی شما
  final String _serverBaseUrl = "https://voice-tutor-backend-co0k.onrender.com";

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = Directory.systemTemp;
      final path = '${dir.path}/input_record.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      _sendToServer(audioFilePath: path);
    }
  }

  Future<void> _sendToServer({String? audioFilePath, String? textMessage}) async {
    setState(() => _isLoading = true);
    final uri = Uri.parse("$_serverBaseUrl/chat-voice");

    var request = http.MultipartRequest("POST", uri);
    request.fields['accent'] = _selectedAccent;
    request.fields['scenario'] = _selectedScenario;
    request.fields['speed'] = _playbackSpeed == 0.8 ? "-20%" : "+0%";

    if (textMessage != null && textMessage.trim().isNotEmpty) {
      request.fields['user_text'] = textMessage;
      setState(() {
        _messages.add({"role": "user", "text": textMessage});
      });
    }

    if (audioFilePath != null) {
      request.files.add(await http.MultipartFile.fromPath('audio_file', audioFilePath));
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setState(() {
          if (audioFilePath != null && data["user_transcription"] != null) {
            _messages.add({"role": "user", "text": data["user_transcription"]});
          }
          _messages.add({
            "role": "assistant",
            "text": data["assistant_reply"] ?? "",
            "feedback": data["feedback"] ?? "",
            "audio_url": "$_serverBaseUrl" + (data["audio_url"] ?? "")
          });
        });

        if (data["audio_url"] != null) {
          await _audioPlayer.play(UrlSource("$_serverBaseUrl" + data["audio_url"]));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${data['error'] ?? 'Server error'}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI English Voice Tutor"),
        backgroundColor: Colors.indigo,
        actions: [
          DropdownButton<double>(
            value: _playbackSpeed,
            dropdownColor: Colors.indigo,
            underline: const SizedBox(),
            icon: const Icon(Icons.speed, color: Colors.white),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: const [
              DropdownMenuItem(value: 0.8, child: Text("0.8x Slow")),
              DropdownMenuItem(value: 1.0, child: Text("1.0x Normal")),
            ],
            onChanged: (val) => setState(() => _playbackSpeed = val!),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ChoiceChip(
                  label: const Text("🇺🇸 American"),
                  selected: _selectedAccent == "american",
                  selectedColor: Colors.indigo.shade200,
                  onSelected: (val) => setState(() => _selectedAccent = "american"),
                ),
                ChoiceChip(
                  label: const Text("🇬🇧 British"),
                  selected: _selectedAccent == "british",
                  selectedColor: Colors.indigo.shade200,
                  onSelected: (val) => setState(() => _selectedAccent = "british"),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.indigo.shade50 : Colors.white,
                      border: Border.all(color: isUser ? Colors.indigo.shade200 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg["text"] ?? "",
                          style: TextStyle(fontSize: 15, color: isUser ? Colors.indigo.shade900 : Colors.black87),
                        ),
                        if (!isUser && msg["feedback"] != null && msg["feedback"]!.isNotEmpty) ...[
                          const Divider(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("💡 ", style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  msg["feedback"]!,
                                  style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isUser && msg["audio_url"] != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () => _audioPlayer.play(UrlSource(msg["audio_url"]!)),
                              child: const Icon(Icons.volume_up, color: Colors.indigo, size: 22),
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "Type in English or tap mic...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: () {
                    if (_textController.text.trim().isNotEmpty) {
                      _sendToServer(textMessage: _textController.text.trim());
                    }
                  },
                ),
                GestureDetector(
                  onTap: _isRecording ? _stopRecordingAndSend : _startRecording,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: _isRecording ? Colors.red : Colors.indigo,
                    child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
