// lib/screens/client/client_mes_recus.dart (Version avec statut)
// ✅ Dans la carte du reçu, ajoutez :

Widget _buildRecuCard(RecuModel recu) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ STATUT AVEC COULEUR
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: recu.statutCouleur.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: recu.statutCouleur,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                recu.statut == 'Total'
                                    ? Icons.check_circle
                                    : recu.statut == 'Partiel'
                                        ? Icons.warning_amber
                                        : Icons.cancel,
                                color: recu.statutCouleur,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                recu.statutTexte,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: recu.statutCouleur,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'N° ${recu.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // ✅ BARRE DE PROGRESSION
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: recu.pourcentagePaye / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: recu.pourcentagePaye >= 100
                                ? Colors.green
                                : recu.pourcentagePaye >= 50
                                    ? Colors.orange
                                    : Colors.red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${recu.annee} - ${recu.periode}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${recu.montant.toStringAsFixed(2)} DH',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: recu.statut == 'Total'
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (recu.montantRestant != null && recu.montantRestant! > 0)
                      Text(
                        '⚠️ Restant: ${recu.montantRestant!.toStringAsFixed(2)} DH',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ... (suite du code)
        ],
      ),
    ),
  );
}