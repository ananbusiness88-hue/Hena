import 'package:flutter/material.dart';

import '../widgets/legal_widgets.dart';

/// The terms and conditions of the "هِنا" application.
///
/// The wording is fixed by the application owner and must not be reworded.
class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPageScaffold(
      title: 'الشروط والأحكام وقواعد الاستخدام — تطبيق "هِنا"',
      icon: Icons.gavel_outlined,
      children: [
        LegalClause(
          number: '1',
          text: 'سياسة إلغاء الطلبات',
          subtitle:
              'يحق للعميل إلغاء الطلب خلال دقيقة واحدة فقط من الضغط على '
              '"إتمام الشراء". بعد مرور الدقيقة، لا يمكن إلغاء الطلب نهائياً '
              'لبدء المتجر في التجهيز.',
        ),
        LegalClause(
          number: '2',
          text: 'سياسة عدم استلام الطلبات',
          subtitle:
              'في حال رفض استلام الطلب بدون سبب مقنع، يتم إيقاف الحساب نهائياً '
              'ووقف العنوان المستخدم ولن يتم التعامل معه مرة أخرى.',
        ),
        LegalClause(
          number: '3',
          text: 'إخلاء المسؤولية',
          subtitle:
              'إدارة تطبيق "هِنا" غير مسؤولة تماماً عن أي تعاملات مالية أو '
              'عمولات جانبية تتم بين العميل والمندوب خارج التطبيق.',
        ),
        LegalClause(
          number: '4',
          text: 'التواصل والشكاوى',
        ),
        LegalContact(
          icon: Icons.email_outlined,
          label: 'البريد الإلكتروني',
          value: 'contact.henaapp@gmail.com',
        ),
        LegalContact(
          icon: Icons.chat_outlined,
          label: 'واتساب',
          value: '01002026939',
        ),
      ],
    );
  }
}
