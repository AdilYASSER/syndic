// lib/models/operation.dart
class Operation {
  final String id;
  final String libelle;
  final DateTime dateOperation;
  final DateTime dateValeur;
  final double debit;
  final double credit;
  final String numPiece;
  final String fichierSource;
  final DateTime dateImport;

  Operation({
    required this.id,
    required this.libelle,
    required this.dateOperation,
    required this.dateValeur,
    required this.debit,
    required this.credit,
    required this.numPiece,
    required this.fichierSource,
    required this.dateImport,
  });

  Map<String, dynamic> toMap() {
    return {
      'libelle': libelle,
      'dateOperation': dateOperation.toIso8601String(),
      'dateValeur': dateValeur.toIso8601String(),
      'debit': debit,
      'credit': credit,
      'numPiece': numPiece,
      'fichierSource': fichierSource,
      'dateImport': dateImport.toIso8601String(),
    };
  }

  factory Operation.fromMap(String id, Map<String, dynamic> map) {
    return Operation(
      id: id,
      libelle: map['libelle'] ?? '',
      dateOperation: DateTime.parse(map['dateOperation']),
      dateValeur: DateTime.parse(map['dateValeur']),
      debit: (map['debit'] ?? 0).toDouble(),
      credit: (map['credit'] ?? 0).toDouble(),
      numPiece: map['numPiece'] ?? '',
      fichierSource: map['fichierSource'] ?? '',
      dateImport: DateTime.parse(map['dateImport']),
    );
  }
}