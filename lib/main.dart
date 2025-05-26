import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:universal_html/html.dart' as html;
import 'package:logger/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:fluent_ui/fluent_ui.dart' hide TreeView, TreeViewItem, FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:http/http.dart' as http;
import 'package:nsfproposalhelper_app/utils.dart';

void main() {
  runApp(const MyApp());
  final logger = AppLog();
  logger.d('App started');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'CRED Proposal Review',
      theme: FluentThemeData(
        buttonTheme: ButtonThemeData(
          filledButtonStyle: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xFF777777);
              } else if (states.contains(WidgetState.pressed)) {
                return const Color(0xFF9552A8);
              } else if (states.contains(WidgetState.hovered)) {
                return const Color(0xFFB67CC2);
              }
              return const Color(0xFFA465B2);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.isDisabled) {
                return Colors.grey; // text color for disabled
              }
              return Colors.white;
            }),
          )
        )
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PlatformFile? pdfFile;
  PlatformFile? csvFile;
  PdfDocument? highlightedPdfDocument;
  Uint8List? highlightedPdfBytes;
  Map<String, dynamic>? flaggedTerms;
  PdfViewerController? _viewerController;
  bool _isLoading = false;

  @override
  initState() {
    super.initState();
  }

  Future<void> pickPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // <-- IMPORTANT: get file bytes directly
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        pdfFile = result.files.single;
      });
    }
  }

  Future<void> pickCsvFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true, // <-- IMPORTANT: get file bytes directly
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        csvFile = result.files.single;
      });
    }
  }

  Future<void> submitFiles() async {
    if (pdfFile == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await flagTerms();

    setState(() {
      highlightedPdfDocument = null;
      highlightedPdfBytes = null;
    });

    if (flaggedTerms!.isNotEmpty) {
      await highlightFile();
    }

    setState(() {
      _viewerController = PdfViewerController();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: const EdgeInsets.all(0),
      header: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey,
              width: 2
            )
          )
        ),
        child: PageHeader(
          title: Padding(
            padding: const EdgeInsets.fromLTRB(0,20,0,0),
            child: Row(
              children: [
                Image.asset('assets/Combination-medium.png', height: 100),
                const SizedBox(width: 20),
                const Text('Proposal Reviewer'),
              ]
            )
          ),
          padding: 10
        ),
      ),
      content: Row(
        children: [
          Container(
            width: 300,
            decoration: const BoxDecoration(
              color: Colors.grey,
              border: Border.symmetric(
                vertical: BorderSide(
                  color: Colors.grey,
                  width: 2
                )
              )
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Button(
                  onPressed: pickPdfFile,
                  child: const Text('Upload PDF'),
                ),
                const SizedBox(height: 20),
                Button(
                  onPressed: pickCsvFile,
                  child: const Text('Upload CSV (optional)'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (pdfFile == null) ? null : submitFiles,
                  child: const Text('Review'),
                ),
                const SizedBox(height: 20),
                if (pdfFile != null)
                  Text('PDF Selected: ${pdfFile!.name}', style: const TextStyle(color: Colors.white)),
                if (csvFile != null)
                  Text('CSV Selected: ${csvFile!.name}', style: const TextStyle(color: Colors.white)),
                if (flaggedTerms != null)
                  ... [
                    const Divider(
                      direction: Axis.horizontal,
                      style: DividerThemeData(
                        decoration: BoxDecoration(
                          color: Colors.white,
                        ),
                        horizontalMargin: EdgeInsets.all(10),
                        thickness: 2
                      )
                    ),
                    if (flaggedTerms!.isEmpty)
                    ... [
                      const Text('No terms flagged for review!', style: TextStyle(color: Colors.white))
                    ] else
                    ... [
                      const Text('The follow terms were flagged for review:', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(
                        '(Total: ${flaggedTerms!.values.map((entry) => entry["count"] as int).fold(0, (sum, count) => sum + count)} | Unique: ${flaggedTerms!.length})',
                        style: const TextStyle(color: Colors.white)
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                          child: FlaggedTermsTreeView(flaggedTerms: flaggedTerms!, onPageSelected: jumpToPdfPage)
                      )
                    ]
                  ]
              ],
            ),
          ),
          const Divider(direction: Axis.horizontal, size: 1),
          Expanded(
            child: (_isLoading)
            ? const Center(child: ProgressRing(activeColor: Color(0xFFA465B2),))
            : (flaggedTerms?.isNotEmpty ?? false)
              ? (highlightedPdfBytes != null)
                ? PdfViewerWithControls(pdfBytes: highlightedPdfBytes!, controller: _viewerController!)
                : const Text('No PDF to display!')
              : const Center(child: Text('No PDF to display. Upload a PDF to review!'))
          )
        ],
      ),
    );
  }

  Future<void> flagTerms() async {
    try {
      var uri = Uri.parse('https://nsf-language-reviewer.onrender.com/flag-terms/');
      var request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'pdf_file',
          pdfFile!.bytes!,
          filename: pdfFile!.name,
        ),
      );

      if (csvFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'excel_file',
            csvFile!.bytes!,
            filename: csvFile!.name,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
          final result = response.body;
          final terms = jsonDecode(result);

          final sortedEntries = terms.entries.toList()
            ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));

          flaggedTerms = Map.fromEntries(sortedEntries);
          
      } else {
        debugPrint("Analysis Failed");
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> highlightFile() async {
    try {
      var uri = Uri.parse('https://nsf-language-reviewer.onrender.com/highlight-terms/');
      var request = http.MultipartRequest('POST', uri);

      
      request.files.add(
        http.MultipartFile.fromBytes(
          'pdf_file',
          pdfFile!.bytes!,
          filename: pdfFile!.name,
        ),
      );

      if (csvFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'excel_file',
            csvFile!.bytes!,
            filename: csvFile!.name,
          ),
        );
      }

      debugPrint('Request Created: $request');

      debugPrint('Awaiting PDF response...');

      var response = await request.send();

      debugPrint('PDF response received: $response');

      if (response.statusCode == 200) {
        highlightedPdfBytes = await response.stream.toBytes();
      } else {
        debugPrint('Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void jumpToPdfPage(int page) {
    if (_viewerController == null) {
      debugPrint('PDF viewer controller is null!');
      return;
    }
    _viewerController!.goToPage(pageNumber: page, anchor: PdfPageAnchor.top, duration: Duration.zero);
    debugPrint('Jumped to page $page');
  }

  List<TreeViewNode<String>> buildResponseTree(Map<String, dynamic> flaggedTerms) {
    return flaggedTerms.entries.map((entry) {
      final String term = entry.key;
      final int count = entry.value['count'];
      final List pages = entry.value['pages'];

      return TreeViewNode<String>(
        '$term ($count)',
        children: pages.map<TreeViewNode<String>>((page) {
          return TreeViewNode<String>('Page $page');
        }).toList(),
      );
    }).toList();
  }
}

class PdfViewerWithControls extends StatefulWidget {
  final Uint8List pdfBytes;
  final PdfViewerController controller;

  const PdfViewerWithControls({super.key, required this.pdfBytes, required this.controller});

  @override
  State<PdfViewerWithControls> createState() => _PdfViewerWithControlsState();
}

class _PdfViewerWithControlsState extends State<PdfViewerWithControls> {
  late PdfDocumentRef _documentRef;
  late PdfDocument _document;
  final TextEditingController _searchController = TextEditingController();
  late final textSearcher = PdfTextSearcher(widget.controller)..addListener(_update);
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

    @override
  void dispose() {
    // dispose the PdfTextSearcher
    textSearcher.removeListener(_update);
    textSearcher.dispose();
    super.dispose();
  }


  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPdf() async {
    _document = await PdfDocument.openData(widget.pdfBytes);
    _documentRef = PdfDocumentRefDirect(_document);
    setState(() => _isLoaded = true);
  }

  void _search(String query) {
    textSearcher.startTextSearch(query, caseInsensitive: true);
  }

  void _downloadPdf() {
    final blob = html.Blob([widget.pdfBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "highlighted.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const Center(child: ProgressRing());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Expanded(
              //   child: TextBox(
              //     controller: _searchController,
              //     placeholder: 'Search in PDF',
              //     onSubmitted: _search,
              //   ),
              // ),
              Expanded(
                child: Center(
                child: FilledButton(
                  onPressed: _downloadPdf,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.arrow_download_20_regular, color: Colors.white),
                      Text('Download Highlighted PDF', style: TextStyle(color: Colors.white)),
                    ]
                  )
                ),
              ))
            ],
          ),
        ),
        Expanded(
          child: PdfViewer(
            _documentRef,
            controller: widget.controller,
            params: PdfViewerParams(
              // add pageTextMatchPaintCallback that paints search hit highlights
              pagePaintCallbacks: [
                textSearcher.pageTextMatchPaintCallback
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FlaggedTermsTreeView extends StatefulWidget {
  final Map<String, dynamic> flaggedTerms;
  final void Function(int) onPageSelected;


  const FlaggedTermsTreeView({
    super.key,
    required this.flaggedTerms,
    required this.onPageSelected,
  });

  @override
  State<FlaggedTermsTreeView> createState() => _FlaggedTermsTreeViewState();
}

class _FlaggedTermsTreeViewState extends State<FlaggedTermsTreeView> {
  final TreeViewController treeController = TreeViewController();
  final ScrollController horizontalController = ScrollController();
  final ScrollController verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    horizontalController.dispose();
    verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TreeView<String>(
      controller: treeController,
      tree: treeNodes,
      verticalDetails: ScrollableDetails.vertical(controller: verticalController),
      horizontalDetails: ScrollableDetails.horizontal(controller: horizontalController),
      treeNodeBuilder: _treeNodeBuilder as TreeViewNodeBuilder,
      treeRowBuilder: (TreeViewNode<String> node) {
        return TreeView.defaultTreeRowBuilder(node).copyWith(
          recognizerFactories: <Type, GestureRecognizerFactory>{
            TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (TapGestureRecognizer t) {
                t.onTap = () {
                  final match = RegExp(r'Page (\d+)').firstMatch(node.content);
                  if (match != null) {
                    final page = int.parse(match.group(1)!);
                    widget.onPageSelected(page);
                  }
                };
              },
            ),
          },
        );
      },
      indentation: TreeViewIndentationType.custom(36),
    );
  }

  List<TreeViewNode<String>> get treeNodes {
    return widget.flaggedTerms.entries.map((entry) {
      final term = entry.key;
      final count = entry.value["count"];
      final pages = List<int>.from(entry.value["pages"]);

      return TreeViewNode<String>(
        '$term ($count)',
        children: pages.map((page) => TreeViewNode<String>('Page $page')).toList(),
      );
    }).toList();
  }

  Widget _treeNodeBuilder(
    BuildContext context,
    TreeViewNode node,
    AnimationStyle animation
  ) {
    final bool isParentNode = node.children.isNotEmpty;
    if (isParentNode) {
      return TreeView.wrapChildToToggleNode(
        node: node,
        child: Row(
          children: <Widget>[
            // Leading icon for parent nodes
            Icon(
              node.isExpanded ? FluentIcons.chevron_down_16_regular : FluentIcons.chevron_right_16_regular,
              size: 10,
              color: Colors.white
            ),
            // Spacer
            const SizedBox(width: 8.0),
            // Content
            Text(node.content, style: const TextStyle(color: Colors.white)),
          ],
        )
      );
    } else {
      return Row(
        children: <Widget>[
          // Spacer
          const SizedBox(width: 8.0),
          // Content
          Text(node.content, style: const TextStyle(color: Colors.white)),
        ],
      );
    }
  }
}