import 'package:flutter/material.dart';

import '../widgets/legal_widgets.dart';

/// The privacy policy of the "هِنا" application.
///
/// The wording is fixed by the application owner and must not be reworded.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPageScaffold(
      title: 'سياسة الخصوصية لتطبيق "هِنا"',
      icon: Icons.privacy_tip_outlined,
      children: [
        LegalParagraph(
          text:
              'نحن في تطبيق "هِنا" نلتزم بحماية خصوصيتك وبياناتك الشخصية.',
        ),
        LegalClause(
          number: '1',
          text: 'البيانات التي نجمعها',
          subtitle:
              'بيانات الحساب (الاسم، رقم الهاتف، البريد الإلكتروني)، بيانات '
              'العناوين داخل حدائق أكتوبر لغرض التوصيل، وبيانات المصادقة المشفرة.',
        ),
        LegalClause(
          number: '2',
          text: 'كيفية استخدام البيانات',
          subtitle:
              'معالجة وتوصيل الطلبات بدقة، التواصل بخصوص حالة الطلب، وتأمين '
              'المنصة ضد الاحتيال.',
        ),
        LegalClause(
          number: '3',
          text: 'حماية البيانات',
          subtitle:
              'نطبق معايير تشفير وأمان عالية (RLS)، ولا نشارك البيانات إلا '
              'بالقدر اللازم مع المندوب والمحل لتنفيذ الطلب.',
        ),
        LegalClause(
          number: '4',
          text: 'الموافقة',
          subtitle:
              'باختيارك خانة الموافقة (Checkbox) عند إنشاء الحساب، تقر '
              'بموافقتك الكاملة على هذه السياسة.',
        ),
      ],
    );
  }
}
