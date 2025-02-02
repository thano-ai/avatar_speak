import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';

void main() {
  runApp(AvatarSpeakerApp());
}

class AvatarSpeakerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Avatar Speaker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AvatarSpeakerHomePage(),
    );
  }
}

class AvatarSpeakerHomePage extends StatefulWidget {
  @override
  _AvatarSpeakerHomePageState createState() => _AvatarSpeakerHomePageState();
}

class _AvatarSpeakerHomePageState extends State<AvatarSpeakerHomePage> {
  final TextEditingController _textController = TextEditingController();
  bool isLoading = false;
  String? videoUrl; // Stores the URL of the generated video
  VideoPlayerController? _videoController;
  String? videoId; // Stores the video ID

  Future<void> generateVideo(String text) async {
    setState(() {
      isLoading = true;
      videoUrl = null; // Reset the video URL
      videoId = null; // Reset the video ID
    });

    var url = Uri.parse('https://api.heygen.com/v2/video/generate');
    var headers = {
      'Content-Type': 'application/json',
      'X-Api-Key': 'MDVlZmNjMGQ3NDgwNDIzNDkzZGJiYzAxNWE1ZDE2NjgtMTczODMwNjc5Nw==', // Replace with your actual API key
    };
    var body = jsonEncode({
      "video_inputs": [
        {
          "character": {
            "type": "avatar",
            "avatar_id": "Gala_sitting_sofa_front_close", // Replace with your desired avatar ID
            "avatar_style": "normal"
          },
          "voice": {
            "type": "text",
            "input_text": text, // Use the text entered by the user
            "voice_id": "26b2064088674c80b1e5fc5ab1a068eb" // Replace with your desired voice ID
          },
          "background": {
            "type": "color",
            "value": "#008000" // Replace with your desired background color
          }
        }
      ],
      "dimension": {
        "width": 1280,
        "height": 720
      }
    });

    try {
      var response = await http.post(url, headers: headers, body: body);
      print('API Response Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        if (responseData['data'] != null && responseData['data']['video_id'] != null) {
          setState(() {
            videoId = responseData['data']['video_id']; // Store the video ID
          });
          checkVideoStatus(); // Start checking the video status
        } else {
          print('Error: video_id not found in the API response');
        }
      } else {
        print('Failed to generate video: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error generating video: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> checkVideoStatus({int retries = 15}) async {
    if (videoId == null) return;

    var url = Uri.parse('https://api.heygen.com/v1/video_status.get?video_id=$videoId');
    var headers = {
      'X-Api-Key': 'MDVlZmNjMGQ3NDgwNDIzNDkzZGJiYzAxNWE1ZDE2NjgtMTczODMwNjc5Nw==',
    };

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        print('🔍 Checking video status (Attempt $attempt)...');
        var response = await http.get(url, headers: headers);
        print('API Response Status Code: ${response.statusCode}');
        print('API Response Body: ${response.body}');

        if (response.statusCode == 200) {
          var responseData = jsonDecode(response.body);
          var status = responseData['data']['status'];

          if (status == 'completed' && responseData['data']['video_url'] != null) {
            setState(() {
              videoUrl = responseData['data']['video_url'];
              _videoController = VideoPlayerController.network(videoUrl!)
                ..initialize().then((_) {
                  setState(() {});
                });
            });
            print("✅ Video is ready: $videoUrl");
            return;
          } else if (status == 'failed') {
            print('❌ Video processing failed.');
            return;
          } else {
            print("⏳ Video still processing (status: $status), retrying...");
          }
        } else {
          print('❌ Failed to check video status: ${response.statusCode}');
        }

        await Future.delayed(Duration(seconds: 30)); // Longer delay
      } catch (e) {
        print('❌ Error checking video status: $e');
      }
    }

    print('🚨 Max retries reached. Video processing might have failed.');
  }



  @override
  void dispose() {
    _videoController?.dispose(); // Clean up the video controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Avatar Speaker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            // Text Input Field
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter text for the avatar to speak',
              ),
            ),
            SizedBox(height: 20),

            // Generate Video Button with Loading Indicator
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                await generateVideo(_textController.text);
              },
              child: isLoading
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Generating...'),
                ],
              )
                  : Text('Generate Video'),
            ),
            SizedBox(height: 20),

            // Show Loading Indicator While Video is Generating
            if (isLoading || (videoId != null && videoUrl == null))
              Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text(
                    "Generating video... Please wait.",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

            // Display Video if Available
            if (videoUrl != null && _videoController != null) ...[
              _videoController!.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
                  : CircularProgressIndicator(),

              SizedBox(height: 10),

              // Video Control Buttons: Play/Pause and Restart
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/Pause Button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    },
                    child: Icon(
                      _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),

                  SizedBox(width: 20), // Space between buttons

                  // Restart Button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _videoController!.seekTo(Duration.zero); // Reset to start
                        _videoController!.play(); // Play from beginning
                      });
                    },
                    child: Icon(Icons.replay), // Restart Icon
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}