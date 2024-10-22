import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FileUploader(),
    );
  }
}

class FileUploader extends StatefulWidget {
  @override
  _FileUploaderState createState() => _FileUploaderState();
}

class _FileUploaderState extends State<FileUploader> {
  File? _file;
  String? _errorMessage;
  bool _loading = false;

  // Function to pick a file
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['txt']);

    if (result != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'No file selected.';
      });
    }
  }

  // Function to upload the file and navigate to a new page with the response
  Future<void> _uploadFile(BuildContext context) async {
    if (_file == null) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.1.14:5000/api/upload_file'));
    request.files.add(await http.MultipartFile.fromPath('file', _file!.path));

    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await http.Response.fromStream(response);
        var responseData = jsonDecode(responseBody.body);

        // Navigate to the new page and pass the response data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DataDisplayPage(responseData),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to upload file: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Text File'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _pickFile,
              child: Text('Choose File'),
            ),
            SizedBox(height: 20),
            _file != null
                ? Text('File selected: ${_file!.path.split('/').last}')
                : Text('No file selected'),
            if (_errorMessage != null) ...[
              SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _uploadFile(context),
              child: Text('Upload File'),
            ),
            SizedBox(height: 20),
            _loading ? CircularProgressIndicator() : Container(),
          ],
        ),
      ),
    );
  }
}

// New page to display the response data
class DataDisplayPage extends StatelessWidget {
  final Map<String, dynamic> data;

  DataDisplayPage(this.data);

  @override
  Widget build(BuildContext context) {
    var wordData = data['data'] as List;
    var multipleTime = data['multiple_execution_time'];
    var soloTime = data['solo_execution_time'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Data Display'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Multi Machine Execution Time: $multipleTime s'),
            Text(''),
            Text('Solo Machine Execution Time: $soloTime s'),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: wordData.length,
                itemBuilder: (context, index) {
                  var word = wordData[index];
                  return ListTile(
                    title: Text(word['word']),
                    subtitle: Text('Count: ${word['count']}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
