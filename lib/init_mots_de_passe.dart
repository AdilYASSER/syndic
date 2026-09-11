// init_mots_de_passe.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('🔥 Firebase initialisé');
  print('🔄 Création de la collection mots_de_passe...');

  final firestore = FirebaseFirestore.instance;

  // ✅ Liste complète des codes par appartement
  final codesParAppartement = {
    // Bloc A (28)
    'A1': '1001', 'A2': '1002', 'A3': '1003', 'A4': '1004',
    'A5': '1005', 'A6': '1006', 'A7': '1007', 'A8': '1008',
    'A9': '1009', 'A10': '1010', 'A11': '1011', 'A12': '1012',
    'A13': '1013', 'A14': '1014', 'A15': '1015', 'A16': '1016',
    'A17': '1017', 'A18': '1018', 'A19': '1019', 'A20': '1020',
    'A21': '1021', 'A22': '1022', 'A23': '1023', 'A24': '1024',
    'A25': '1025', 'A26': '1026', 'A27': '1027', 'A28': '1028',
    // Bloc B (32)
    'B1': '1029', 'B2': '1030', 'B3': '1031', 'B4': '1032',
    'B5': '1033', 'B6': '1034', 'B7': '1035', 'B8': '1036',
    'B9': '1037', 'B10': '1038', 'B11': '1039', 'B12': '1040',
    'B13': '1041', 'B14': '1042', 'B15': '1043', 'B16': '1044',
    'B17': '1045', 'B18': '1046', 'B19': '1047', 'B20': '1048',
    'B21': '1049', 'B22': '1050', 'B23': '1051', 'B24': '1052',
    'B25': '1053', 'B26': '1054', 'B27': '1055', 'B28': '1056',
    'B29': '1057', 'B30': '1058', 'B31': '1059', 'B32': '1060',
    // Bloc C (36)
    'C1': '1061', 'C2': '1062', 'C3': '1063', 'C4': '1064',
    'C5': '1065', 'C6': '1066', 'C7': '1067', 'C8': '1068',
    'C9': '1069', 'C10': '1070', 'C11': '1071', 'C12': '1072',
    'C13': '1073', 'C14': '1074', 'C15': '1075', 'C16': '1076',
    'C17': '1077', 'C18': '1078', 'C19': '1079', 'C20': '1080',
    'C21': '1081', 'C22': '1082', 'C23': '1083', 'C24': '1084',
    'C25': '1085', 'C26': '1086', 'C27': '1087', 'C28': '1088',
    'C29': '1089', 'C30': '1090', 'C31': '1091', 'C32': '1092',
    'C33': '1093', 'C34': '1094', 'C35': '1095', 'C36': '1096',
    // Bloc D (32)
    'D1': '1097', 'D2': '1098', 'D3': '1099', 'D4': '1100',
    'D5': '1101', 'D6': '1102', 'D7': '1103', 'D8': '1104',
    'D9': '1105', 'D10': '1106', 'D11': '1107', 'D12': '1108',
    'D13': '1109', 'D14': '1110', 'D15': '1111', 'D16': '1112',
    'D17': '1113', 'D18': '1114', 'D19': '1115', 'D20': '1116',
    'D21': '1117', 'D22': '1118', 'D23': '1119', 'D24': '1120',
    'D25': '1121', 'D26': '1122', 'D27': '1123', 'D28': '1124',
    'D29': '1125', 'D30': '1126', 'D31': '1127', 'D32': '1128',
    // Intervenants
    'INTERVENANT_1': '2001',
    'INTERVENANT_2': '2002',
    'INTERVENANT_3': '2003',
    'INTERVENANT_4': '2004',
  };

  int count = 0;
  int total = codesParAppartement.length;

  for (var entry in codesParAppartement.entries) {
    final numAppartement = entry.key;
    final codeInitial = entry.value;

    // Vérifier si le document existe déjà
    final snapshot = await firestore
        .collection('mots_de_passe')
        .where('numAppartement', isEqualTo: numAppartement)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      print('⚠️ $numAppartement existe déjà (${snapshot.docs.first.id})');
      count++;
      continue;
    }

    // Créer le document
    await firestore.collection('mots_de_passe').add({
      'numAppartement': numAppartement,
      'codeInitial': codeInitial,
      'motDePasseActuel': codeInitial,
      'aChange': false,
      'dateCreation': FieldValue.serverTimestamp(),
    });

    count++;
    print('✅ $numAppartement → $codeInitial (${count}/$total)');
  }

  print('\n✅ $count codes créés avec succès !');
  print('📊 Total: $total');
  
  // Afficher le récapitulatif par bloc
  print('\n📊 RÉCAPITULATIF PAR BLOC:');
  print('  Bloc A: 28 codes (1001-1028)');
  print('  Bloc B: 32 codes (1029-1060)');
  print('  Bloc C: 36 codes (1061-1096)');
  print('  Bloc D: 32 codes (1097-1128)');
  print('  Intervenants: 4 codes (2001-2004)');
  print('  TOTAL: 132 codes');
}