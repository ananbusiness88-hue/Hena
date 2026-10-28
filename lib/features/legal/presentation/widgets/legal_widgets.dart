import 'package:flutter/material.dart';

/// Shared shell for the legal pages (privacy policy and terms).
///
/// Both documents share the same look: an RTL app bar, a scrollable body with
/// numbered clauses, and a footer that carries the contact details.
class LegalPageScaffold extends StatelessWidget {
  const LegalPageScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  static const _green = Color(0xFF087A4B);
  static const _darkGreen = Color(0xFF123F2F);
  static const _muted = Color(0xFF63766A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF8),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: _darkGreen),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _darkGreen,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  _Header(icon: icon),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFD8E9E0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The banner at the top of a legal page.
class LegalHeader extends StatelessWidget {
  const LegalHeader({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE4F4E9), Color(0xFFF7FBF8)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD3EADC)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: LegalPageScaffold._green, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'تطبيق "هِنا" للتوصيل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LegalPageScaffold._darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered clause inside a legal document.
class LegalClause extends StatelessWidget {
  const LegalClause({
    super.key,
    required this.number,
    required this.text,
    this.subtitle,
  });

  final String number;
  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F4E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: LegalPageScaffold._green,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Color(0xFF162A21),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: LegalPageScaffold._muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain paragraph inside a legal document.
class LegalParagraph extends StatelessWidget {
  const LegalParagraph({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.65,
          color: Color(0xFF162A21),
        ),
      ),
    );
  }
}

/// A contact line (email / WhatsApp).
class LegalContact extends StatelessWidget {
  const LegalContact({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: LegalPageScaffold._green),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: LegalPageScaffold._muted,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF162A21),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The private helpers are exposed through the public widgets above; these
// aliases keep the underscore-prefixed members of the scaffold usable from
// the document pages.
class _Header extends LegalHeader {
  const _Header({required super.icon});
}
