import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../services/disease_database_service.dart';
import '../core/services/backend_config.dart';

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({Key? key}) : super(key: key);
      final uri = BackendConfig.apiUri('/api/predict_disease');
  @override
  State<DiseaseDetectionScreen> createState() =>
      _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _diseaseResult;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _savedAnalyses = [];
  String? _cropType = 'Unknown';
  final String _fieldName = 'Default Field';
  late TextEditingController _notesController;
  late TextEditingController _fieldNameController;
  Map<String, dynamic>? _statistics;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _fieldNameController = TextEditingController(text: _fieldName);
    _loadSavedAnalyses();
    _loadStatistics();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _fieldNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAnalyses() async {
    final analyses = await DiseaseDatabaseService.getAllAnalyses();
    setState(() {
      _savedAnalyses = analyses;
    });
  }

  Future<void> _loadStatistics() async {
    final stats = await DiseaseDatabaseService.getStatistics();
    setState(() {
      _statistics = stats;
    });
  }

  Future<void> _saveDiseaseResult() async {
    if (_diseaseResult == null || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No analysis to save')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final id = await DiseaseDatabaseService.saveDiseaseAnalysis(
        imagePath: _selectedImage!.path,
        disease: _diseaseResult!['disease'] ?? 'Unknown',
        confidence: (_diseaseResult!['confidence'] ?? 0).toDouble(),
        symptoms: _diseaseResult!['symptoms'] ?? '',
        treatment: _diseaseResult!['treatment'] ?? '',
        prevention: _diseaseResult!['prevention'] ?? '',
        imageAnalysis: jsonEncode(
          _diseaseResult!['detailed_analysis']?['image_analysis'] ?? {},
        ),
        recommendation:
            _diseaseResult!['detailed_analysis']?['recommendation'] ?? '',
        actionItems: jsonEncode(
          _diseaseResult!['detailed_analysis']?['action_items'] ?? [],
        ),
        cropType: _cropType ?? 'Unknown',
        fieldName: _fieldNameController.text.isEmpty
            ? 'Default Field'
            : _fieldNameController.text,
        notes: _notesController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (id != -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis saved successfully!')),
        );
        _loadSavedAnalyses();
        _loadStatistics();
        _notesController.clear();
        _selectedImage = null;
        _diseaseResult = null;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save analysis')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteAnalysis(int id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Analysis'),
        content: const Text('Are you sure you want to delete this analysis?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await DiseaseDatabaseService.deleteAnalysis(id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis deleted')),
        );
        _loadSavedAnalyses();
        _loadStatistics();
      }
    }
  }

  void _showAnalysisDetails(Map<String, dynamic> analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(analysis['disease'] ?? 'Unknown'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (analysis['imagePath'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(analysis['imagePath']),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Disease: ${analysis['disease'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Confidence: ${((analysis['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
              ),
              Text('Crop: ${analysis['cropType'] ?? 'Unknown'}'),
              Text('Field: ${analysis['fieldName'] ?? 'Default'}'),
              Text('Date: ${analysis['timestamp'] ?? 'N/A'}'),
              if (analysis['notes'] != null && analysis['notes'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Notes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(analysis['notes']),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _diseaseResult = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _detectDisease() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please select an image first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _diseaseResult = null;
    });

    try {
      final uri = BackendConfig.apiUri('/api/predict_disease');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('image', _selectedImage!.path),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        setState(() {
          _diseaseResult = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Backend error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: Could not connect to backend';
        _isLoading = false;
      });
    }
  }

  Widget _buildResultCard(
    String title,
    String content,
    Color backgroundColor,
  ) =>
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2c3e50),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildAnalysisCard(
    String title,
    dynamic data, {
    bool isText = false,
  }) {
    if (isText && data is Map && data['text'] != null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: const Color(0xFFe3f2fd),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data['text'].toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2c3e50),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (data is Map && data.isNotEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: const Color(0xFFf3e5f5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
              const SizedBox(height: 8),
              ...data.entries.map<Widget>((entry) {
                final key =
                    entry.key.toString().replaceAll('_', ' ').toUpperCase();
                final value = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF555555),
                        ),
                      ),
                      Text(
                        value.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF27ae60),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('🖼️ Disease Guard'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '📸 New Analysis'),
            Tab(text: '📋 History'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _buildAnalysisTab(),
          _buildHistoryTab(),
        ],
      ),
    ),
  );

  Widget _buildAnalysisTab() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF8E1),
          Color(0xFFFFEBD7),
        ],
      ),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Leaf Image',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF27ae60),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF2ecc71),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      height: 300,
                      width: double.infinity,
                    )
                  : Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No image selected',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ecc71),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27ae60),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _cropType,
                  items: [
                    'Wheat',
                    'Rice',
                    'Corn',
                    'Potato',
                    'Tomato',
                    'Apple',
                    'Grape',
                    'Unknown'
                  ]
                      .map((crop) => DropdownMenuItem(
                            value: crop,
                            child: Text(crop),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _cropType = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Crop Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _fieldNameController,
                  decoration: InputDecoration(
                    labelText: 'Field Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isLoading || _selectedImage == null ? null : _detectDisease,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(
                _isLoading ? 'Analyzing...' : 'Detect Disease',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2ecc71),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFffe0e0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFe74c3c),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFe74c3c),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFe74c3c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_diseaseResult != null) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: const Color(0xFFffe0e0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Color(0xFFe74c3c),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _diseaseResult!['disease'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFe74c3c),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Confidence: ',
                          style: TextStyle(
                            color: Color(0xFF2c3e50),
                          ),
                        ),
                        Text(
                          '${((_diseaseResult!['confidence'] ?? 0) * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFe74c3c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _diseaseResult!['confidence'] ?? 0,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFe74c3c),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildResultCard(
              '🔍 Symptoms',
              _diseaseResult!['symptoms'] ?? 'No symptoms data',
              const Color(0xFFfff9c4),
            ),
            const SizedBox(height: 12),
            _buildResultCard(
              '💊 Treatment',
              _diseaseResult!['treatment'] ?? 'No treatment data',
              const Color(0xFFd1c4e9),
            ),
            const SizedBox(height: 12),
            _buildResultCard(
              '🛡️ Prevention',
              _diseaseResult!['prevention'] ?? 'No prevention data',
              const Color(0xFFc8e6c9),
            ),
            if (_diseaseResult!['detailed_analysis'] != null) ...[
              const SizedBox(height: 24),
              const Text(
                '📊 Detailed Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF27ae60),
                ),
              ),
              const SizedBox(height: 12),
              _buildAnalysisCard(
                '🏥 Health Assessment',
                _diseaseResult!['detailed_analysis']['image_analysis'] ?? {},
              ),
              const SizedBox(height: 12),
              _buildAnalysisCard(
                '🎯 Recommendation',
                {
                  'text': _diseaseResult!['detailed_analysis']
                          ['recommendation'] ??
                      ''
                },
                isText: true,
              ),
              const SizedBox(height: 12),
              if (_diseaseResult!['detailed_analysis']['action_items'] !=
                  null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  color: const Color(0xFFe8f5e9),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✅ Action Items',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2c3e50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_diseaseResult!['detailed_analysis']
                                ['action_items'] as List)
                            .map<Widget>(
                              (item) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  item.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2c3e50),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            const Text(
              'Add Notes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF27ae60),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any additional notes about this analysis...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveDiseaseResult,
                icon: const Icon(Icons.save),
                label: const Text('Save Analysis'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF2ecc71),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildHistoryTab() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF8E1),
          Color(0xFFFFEBD7),
        ],
      ),
    ),
    child: _savedAnalyses.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No saved analyses yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: [
              if (_statistics != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_statistics!['totalAnalyses'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF27ae60),
                            ),
                          ),
                          const Text('Total'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${(_statistics!['averageConfidence'] ?? 0 * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ecc71),
                            ),
                          ),
                          const Text('Avg Confidence'),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedAnalyses.length,
                  itemBuilder: (context, index) {
                    final analysis = _savedAnalyses[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(analysis['imagePath']),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image_not_supported),
                              ),
                          ),
                        ),
                        title: Text(
                          analysis['disease'] ?? 'Unknown Disease',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Field: ${analysis['fieldName']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Crop: ${analysis['cropType']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Confidence: ${(((analysis['confidence'] ?? 0) as num) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('View Details'),
                              onTap: () {
                                _showAnalysisDetails(analysis);
                              },
                            ),
                            PopupMenuItem(
                              child: const Text('Delete'),
                              onTap: () {
                                _deleteAnalysis(analysis['id']);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );
}
