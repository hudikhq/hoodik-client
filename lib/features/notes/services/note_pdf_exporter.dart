import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Renders a markdown note to a PDF and hands it to the platform share
/// sheet. Hits a small subset of CommonMark (headings, paragraphs,
/// emphasis, links, lists, code blocks, blockquotes, horizontal rules,
/// inline code) — enough for the kinds of notes users actually write.
/// Tables and images are left as plaintext fallbacks; we can add
/// proper rendering once there's user demand.
Future<void> exportNoteToPdf({
  required String markdown,
  required String fileName,
}) async {
  final bytes = await _buildPdf(markdown: markdown, fileName: fileName);
  await Printing.sharePdf(bytes: bytes, filename: _safePdfName(fileName));
}

String _safePdfName(String fileName) {
  final base = fileName.toLowerCase().endsWith('.md')
      ? fileName.substring(0, fileName.length - 3)
      : fileName;
  return '$base.pdf';
}

Future<Uint8List> _buildPdf({
  required String markdown,
  required String fileName,
}) async {
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(markdown.split('\n'));

  // Bundle a real font so unicode (em-dash, smart quotes, code symbols)
  // renders cleanly across platforms — the default Helvetica only
  // supports basic Latin.
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final italic = await PdfGoogleFonts.notoSansItalic();
  final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
  final mono = await PdfGoogleFonts.jetBrainsMonoRegular();

  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    italic: italic,
    boldItalic: boldItalic,
  );

  final renderer = _MarkdownToPdf(monoFont: mono);
  final blocks = renderer.renderBlocks(nodes);

  final doc = pw.Document(theme: theme, title: fileName);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 56),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
        ),
      ),
      build: (ctx) => blocks,
    ),
  );

  return doc.save();
}

class _MarkdownToPdf {
  _MarkdownToPdf({required this.monoFont});

  final pw.Font monoFont;

  /// Top-level entry point. Walks the parsed markdown nodes once and
  /// emits one [pw.Widget] per block-level element. Each block carries
  /// its own bottom margin so the page reads with consistent rhythm.
  List<pw.Widget> renderBlocks(List<md.Node> nodes) {
    final out = <pw.Widget>[];
    for (final node in nodes) {
      final widget = _renderBlock(node);
      if (widget != null) out.add(widget);
    }
    return out;
  }

  pw.Widget? _renderBlock(md.Node node) {
    if (node is md.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return _paragraph([pw.TextSpan(text: text)]);
    }
    if (node is! md.Element) return null;

    switch (node.tag) {
      case 'h1':
        return _heading(node, 24, weight: pw.FontWeight.bold);
      case 'h2':
        return _heading(node, 20, weight: pw.FontWeight.bold);
      case 'h3':
        return _heading(node, 17, weight: pw.FontWeight.bold);
      case 'h4':
        return _heading(node, 15, weight: pw.FontWeight.bold);
      case 'h5':
      case 'h6':
        return _heading(node, 13, weight: pw.FontWeight.bold);
      case 'p':
        return _paragraph(_inlineSpans(node.children ?? const []));
      case 'ul':
        return _list(node, ordered: false);
      case 'ol':
        return _list(node, ordered: true);
      case 'pre':
        return _codeBlock(node);
      case 'blockquote':
        return _blockquote(node);
      case 'hr':
        return pw.Container(
          height: 1,
          color: PdfColors.grey400,
          margin: const pw.EdgeInsets.symmetric(vertical: 12),
        );
      default:
        // Unknown block — render its children inline as a paragraph
        // fallback so content is never silently dropped.
        return _paragraph(_inlineSpans(node.children ?? const []));
    }
  }

  pw.Widget _heading(md.Element node, double size, {pw.FontWeight? weight}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: _inlineSpans(node.children ?? const []),
          style: pw.TextStyle(fontSize: size, fontWeight: weight),
        ),
      ),
    );
  }

  pw.Widget _paragraph(List<pw.InlineSpan> spans) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          children: spans,
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
        ),
      ),
    );
  }

  /// Renders ordered/unordered lists. Each item becomes a row of
  /// `marker + content` so multi-line items wrap under their own marker
  /// instead of under the bullet column.
  pw.Widget _list(md.Element node, {required bool ordered}) {
    final items = (node.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((e) => e.tag == 'li')
        .toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 12, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: ordered ? 22 : 14,
                    child: pw.Text(
                      ordered ? '${i + 1}.' : '•',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: _inlineSpans(items[i].children ?? const []),
                        style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _codeBlock(md.Element node) {
    // Markdown's `<pre>` wraps a `<code>` whose text is the source
    // (already without trailing newline normalization). Strip the
    // wrapper to get at the body.
    final inner = (node.children ?? const <md.Node>[]).firstOrNull;
    final text = inner is md.Element
        ? _collectText(inner.children ?? const [])
        : (inner is md.Text ? inner.text : '');
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: monoFont, fontSize: 10, lineSpacing: 2),
        ),
      ),
    );
  }

  pw.Widget _blockquote(md.Element node) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.grey400, width: 3),
          ),
        ),
        padding: const pw.EdgeInsets.fromLTRB(10, 4, 4, 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final child in node.children ?? const <md.Node>[])
              _renderBlock(child) ?? pw.SizedBox(),
          ],
        ),
      ),
    );
  }

  /// Walk inline children of a block and emit `TextSpan`s. Nested
  /// emphasis (`***foo***`) merges weights/styles by carrying parent
  /// style overrides down through the recursion.
  List<pw.InlineSpan> _inlineSpans(
    List<md.Node> children, {
    pw.TextStyle? parentStyle,
  }) {
    final out = <pw.InlineSpan>[];
    for (final child in children) {
      if (child is md.Text) {
        out.add(pw.TextSpan(text: child.text, style: parentStyle));
        continue;
      }
      if (child is! md.Element) continue;

      switch (child.tag) {
        case 'strong':
          out.addAll(
            _inlineSpans(
              child.children ?? const [],
              parentStyle: _merge(
                parentStyle,
                pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          );
        case 'em':
          out.addAll(
            _inlineSpans(
              child.children ?? const [],
              parentStyle: _merge(
                parentStyle,
                pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ),
            ),
          );
        case 'del':
          out.addAll(
            _inlineSpans(
              child.children ?? const [],
              parentStyle: _merge(
                parentStyle,
                const pw.TextStyle(decoration: pw.TextDecoration.lineThrough),
              ),
            ),
          );
        case 'code':
          // Inline code — monospaced, faint background hard to render
          // in a TextSpan so we settle for the font swap alone.
          out.add(
            pw.TextSpan(
              text: _collectText(child.children ?? const []),
              style: _merge(
                parentStyle,
                pw.TextStyle(font: monoFont, color: PdfColors.deepOrange700),
              ),
            ),
          );
        case 'a':
          final href = child.attributes['href'] ?? '';
          out.add(
            pw.TextSpan(
              annotation: href.isNotEmpty ? pw.AnnotationUrl(href) : null,
              children: _inlineSpans(
                child.children ?? const [],
                parentStyle: _merge(
                  parentStyle,
                  const pw.TextStyle(
                    color: PdfColors.blue700,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
            ),
          );
        case 'br':
          out.add(const pw.TextSpan(text: '\n'));
        default:
          // Unknown inline tag: render its plain text so the user
          // never sees gaps where exotic markdown was used.
          out.addAll(
            _inlineSpans(child.children ?? const [], parentStyle: parentStyle),
          );
      }
    }
    return out;
  }

  pw.TextStyle _merge(pw.TextStyle? base, pw.TextStyle override) {
    return base == null
        ? override
        : base.copyWith(
            font: override.font ?? base.font,
            fontWeight: override.fontWeight ?? base.fontWeight,
            fontStyle: override.fontStyle ?? base.fontStyle,
            color: override.color ?? base.color,
            decoration: override.decoration ?? base.decoration,
          );
  }

  /// Recursively flatten an element tree into a single string. Used by
  /// inline `<code>` and the code-block path where we don't care about
  /// nested formatting.
  String _collectText(List<md.Node> nodes) {
    final buf = StringBuffer();
    for (final n in nodes) {
      if (n is md.Text) {
        buf.write(n.text);
      } else if (n is md.Element) {
        buf.write(_collectText(n.children ?? const []));
      }
    }
    return buf.toString();
  }
}
