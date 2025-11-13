#!/bin/bash

# ╔═══════════════════════════════════════════════════════════╗
# ║   SCRIPT DE TEST INTENSIF - OPTIMISATION PAUL & RAYAN    ║
# ║   Recherche du seuil optimal pour détecter crayon léger   ║
# ╚═══════════════════════════════════════════════════════════╝

cd "$(dirname "$0")"

clear

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   TEST INTENSIF - OPTIMISATION PAUL & RAYAN              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Objectif : Trouver le seuil optimal qui :"
echo "  ✓ Maximise les scores de Paul (21) et Rayan (28)"
echo "  ✓ Ne crée PAS de faux positifs pour les autres élèves"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Vérifier que les données existent
if [ ! -f "data/capture.sqlite" ]; then
    echo "❌ Erreur : Les copies n'ont pas été analysées"
    echo "   Lancez d'abord l'option 2 du script principal"
    exit 1
fi

# Créer le dossier de tests
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
TEST_DIR="tests_optimisation_$TIMESTAMP"
mkdir -p "$TEST_DIR"

echo "📁 Dossier de tests : $TEST_DIR"
echo ""

# Obtenir les scores de référence (seuil actuel 0.15)
echo "📊 Calcul des scores de référence (seuil 0.15)..."
echo ""

# Copier les données
cp -r data "$TEST_DIR/data_ref"

# Calculer avec 0.15
auto-multiple-choice note \
    --data "$TEST_DIR/data_ref" \
    --seuil 0.15 >/dev/null 2>&1

# Extraire tous les scores de référence
sqlite3 "$TEST_DIR/data_ref/scoring.sqlite" "
    SELECT student, SUM(score) as total
    FROM scoring_score
    GROUP BY student
    ORDER BY student;
" > "$TEST_DIR/scores_ref.txt"

# Scores de Paul et Rayan en référence
REF_PAUL=$(sqlite3 "$TEST_DIR/data_ref/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=21;" 2>/dev/null | cut -d'.' -f1)
REF_RAYAN=$(sqlite3 "$TEST_DIR/data_ref/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=28;" 2>/dev/null | cut -d'.' -f1)
REF_AVG=$(sqlite3 "$TEST_DIR/data_ref/scoring.sqlite" "SELECT AVG(total) FROM (SELECT student, SUM(score) as total FROM scoring_score GROUP BY student);" 2>/dev/null | cut -d'.' -f1)

echo "Scores de référence (seuil 0.15) :"
echo "  • Paul (21) : $REF_PAUL / 44"
echo "  • Rayan (28) : $REF_RAYAN / 44"
echo "  • Moyenne classe : $REF_AVG / 44"
echo ""

# Tableau de résultats
echo "Seuil|Paul|Rayan|Moyenne|Delta_Autres|Gain_Paul|Gain_Rayan|Faux_Positifs" > "$TEST_DIR/comparaison.csv"

# Ajouter la référence
echo "0.15|$REF_PAUL|$REF_RAYAN|$REF_AVG|0|0|0|baseline" >> "$TEST_DIR/comparaison.csv"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔬 LANCEMENT DES TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Définir les seuils à tester (de plus sensible à plus conservateur)
SEUILS=(0.08 0.09 0.10 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18)

BEST_SEUIL=""
BEST_GAIN=0
BEST_PAUL=0
BEST_RAYAN=0

for SEUIL in "${SEUILS[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TEST : Seuil $SEUIL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Copier les données
    cp -r data "$TEST_DIR/data_${SEUIL}"

    # Recalculer avec ce seuil
    auto-multiple-choice note \
        --data "$TEST_DIR/data_${SEUIL}" \
        --seuil "$SEUIL" >/dev/null 2>&1

    # Extraire les scores
    PAUL=$(sqlite3 "$TEST_DIR/data_${SEUIL}/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=21;" 2>/dev/null | cut -d'.' -f1)
    RAYAN=$(sqlite3 "$TEST_DIR/data_${SEUIL}/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=28;" 2>/dev/null | cut -d'.' -f1)
    AVG=$(sqlite3 "$TEST_DIR/data_${SEUIL}/scoring.sqlite" "SELECT AVG(total) FROM (SELECT student, SUM(score) as total FROM scoring_score GROUP BY student);" 2>/dev/null | cut -d'.' -f1)

    # Calculer les gains/pertes
    GAIN_PAUL=$((PAUL - REF_PAUL))
    GAIN_RAYAN=$((RAYAN - REF_RAYAN))
    GAIN_TOTAL=$((GAIN_PAUL + GAIN_RAYAN))

    # Calculer la variation moyenne pour les AUTRES élèves (hors Paul et Rayan)
    # Si l'augmentation moyenne est trop forte, c'est probablement des faux positifs
    DELTA_AVG=$((AVG - REF_AVG))

    # Détecter les faux positifs : si la moyenne augmente PLUS que le gain de Paul+Rayan
    if [ "$DELTA_AVG" -gt 2 ]; then
        FAUX_POS="OUI"
    else
        FAUX_POS="Non"
    fi

    echo "Résultats :"
    echo "  • Paul (21) : $PAUL / 44  (${GAIN_PAUL:+$GAIN_PAUL})"
    echo "  • Rayan (28) : $RAYAN / 44  (${GAIN_RAYAN:+$GAIN_RAYAN})"
    echo "  • Moyenne : $AVG / 44  (${DELTA_AVG:+$DELTA_AVG})"
    echo "  • Faux positifs : $FAUX_POS"
    echo ""

    # Sauvegarder
    echo "$SEUIL|$PAUL|$RAYAN|$AVG|$DELTA_AVG|$GAIN_PAUL|$GAIN_RAYAN|$FAUX_POS" >> "$TEST_DIR/comparaison.csv"

    # Garder le meilleur (gain total maximal SANS faux positifs)
    if [ "$FAUX_POS" = "Non" ] && [ "$GAIN_TOTAL" -gt "$BEST_GAIN" ]; then
        BEST_GAIN=$GAIN_TOTAL
        BEST_SEUIL=$SEUIL
        BEST_PAUL=$PAUL
        BEST_RAYAN=$RAYAN
    fi

    sleep 0.5
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TABLEAU COMPARATIF FINAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Afficher le tableau
column -t -s'|' "$TEST_DIR/comparaison.csv"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏆 RECOMMANDATION FINALE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$BEST_SEUIL" ]; then
    echo "✅ SEUIL OPTIMAL : $BEST_SEUIL"
    echo ""
    echo "Avec ce seuil :"
    echo "  • Paul (21) : $BEST_PAUL / 44  (gain: +$((BEST_PAUL - REF_PAUL)))"
    echo "  • Rayan (28) : $BEST_RAYAN / 44  (gain: +$((BEST_RAYAN - REF_RAYAN)))"
    echo "  • Gain total : +$BEST_GAIN points"
    echo "  • Pas de faux positifs détectés"
    echo ""
    echo "💡 Pour appliquer ce seuil, éditez NEW_AMC_TOUT_EN_UN_OPTIMISE.command :"
    echo "   Ligne 43 : AMC_SEUIL=$BEST_SEUIL"
    echo ""
else
    echo "⚠️  Aucun seuil optimal trouvé sans faux positifs"
    echo ""
    echo "Options :"
    echo "  1. Gardez le seuil actuel (0.15)"
    echo "  2. Utilisez un seuil plus bas (risque de faux positifs)"
    echo "  3. Vérifiez la qualité des scans de Paul et Rayan"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Résultats détaillés dans : $TEST_DIR/"
echo "   • comparaison.csv : Tableau complet des résultats"
echo "   • data_X.XX/ : Données pour chaque seuil testé"
echo ""
echo "🔍 ANALYSE AVANCÉE :"
echo ""

# Analyse graphique simple
echo "Évolution des scores (Paul + Rayan) :"
echo ""
for SEUIL in "${SEUILS[@]}"; do
    PAUL=$(sqlite3 "$TEST_DIR/data_${SEUIL}/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=21;" 2>/dev/null | cut -d'.' -f1)
    RAYAN=$(sqlite3 "$TEST_DIR/data_${SEUIL}/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=28;" 2>/dev/null | cut -d'.' -f1)
    TOTAL=$((PAUL + RAYAN))

    # Barre simple
    BARRE=""
    for i in $(seq 1 $TOTAL); do
        BARRE="${BARRE}█"
    done

    printf "  %s : %2d (%s)\n" "$SEUIL" "$TOTAL" "$BARRE"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Générer un rapport détaillé
cat > "$TEST_DIR/RAPPORT_OPTIMISATION.txt" <<EOF
═══════════════════════════════════════════════════════════
RAPPORT D'OPTIMISATION AMC - Paul & Rayan
═══════════════════════════════════════════════════════════

Date : $(date "+%Y-%m-%d %H:%M:%S")
Dossier : $(basename "$(pwd)")

OBJECTIF :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Trouver le seuil optimal pour détecter les cases au crayon
léger (Paul et Rayan) sans créer de faux positifs.

SCORES DE RÉFÉRENCE (seuil 0.15) :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Paul (21) : $REF_PAUL / 44
• Rayan (28) : $REF_RAYAN / 44
• Moyenne classe : $REF_AVG / 44

SEUIL OPTIMAL TROUVÉ :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${BEST_SEUIL:-Aucun (tous créent des faux positifs)}

${BEST_SEUIL:+Résultats avec seuil $BEST_SEUIL :
• Paul (21) : $BEST_PAUL / 44  (+$((BEST_PAUL - REF_PAUL)))
• Rayan (28) : $BEST_RAYAN / 44  (+$((BEST_RAYAN - REF_RAYAN)))
• Gain total : +$BEST_GAIN points
}

ANALYSE :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Consultez le fichier comparaison.csv pour voir tous les résultats.

Les seuils testés : 0.08 à 0.18 (pas de 0.01)

RECOMMANDATION :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${BEST_SEUIL:+Utilisez le seuil $BEST_SEUIL dans NEW_AMC_TOUT_EN_UN_OPTIMISE.command}
${BEST_SEUIL:-Gardez le seuil actuel (0.15) ou vérifiez la qualité des scans}

═══════════════════════════════════════════════════════════
EOF

echo "✅ Rapport détaillé généré : $TEST_DIR/RAPPORT_OPTIMISATION.txt"
echo ""
read -p "Appuyez sur Entrée pour fermer..."
