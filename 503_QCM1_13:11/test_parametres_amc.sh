#!/bin/bash

# ╔═══════════════════════════════════════════════════════════╗
# ║         SCRIPT DE TEST DES PARAMÈTRES AMC                 ║
# ║         Pour trouver la configuration optimale            ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Ce script teste plusieurs configurations de paramètres AMC
# pour trouver celle qui minimise les faux positifs tout en
# détectant les cases légèrement cochées au crayon.

cd "$(dirname "$0")"

clear

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         TEST DES PARAMÈTRES AMC                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Vérifier que les données de base existent
if [ ! -f "data/layout.sqlite" ]; then
    echo "❌ Erreur : Le layout n'a pas été généré"
    echo "   Lancez d'abord l'option 1 du script principal"
    exit 1
fi

if [ ! -d "scans" ] || [ $(ls -1 scans/*.png 2>/dev/null | wc -l) -eq 0 ]; then
    echo "❌ Erreur : Aucun scan trouvé dans scans/"
    exit 1
fi

# Créer un dossier de sauvegarde des résultats
mkdir -p tests_parametres
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

echo "📋 CONFIGURATIONS À TESTER :"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Selon la documentation AMC et les meilleures pratiques :"
echo ""
echo "  • Cases VIDES mesurent : ~0.7-1% de noirceur"
echo "  • Cases COCHÉES au stylo : 15-30% de noirceur"
echo "  • Cases COCHÉES au crayon léger : 8-15% de noirceur"
echo ""
echo "Les configurations suivantes seront testées :"
echo ""
echo "  1. Paramètres ACTUELS (trop sensibles)"
echo "     AMC_SEUIL=0.03, AMC_BW_THRESHOLD=0.15"
echo ""
echo "  2. Paramètres CONSERVATEURS (recommandés)"
echo "     AMC_SEUIL=0.08, AMC_BW_THRESHOLD=0.25"
echo ""
echo "  3. Paramètres ÉQUILIBRÉS"
echo "     AMC_SEUIL=0.10, AMC_BW_THRESHOLD=0.25"
echo ""
echo "  4. Paramètres pour CRAYON TRÈS LÉGER"
echo "     AMC_SEUIL=0.06, AMC_BW_THRESHOLD=0.20"
echo ""
echo "  5. Paramètres pour STYLO SEULEMENT"
echo "     AMC_SEUIL=0.12, AMC_BW_THRESHOLD=0.30"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fonction pour tester une configuration
test_config() {
    local NUM=$1
    local SEUIL=$2
    local BW_THRESHOLD=$3
    local DESCRIPTION=$4

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TEST $NUM : $DESCRIPTION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Paramètres :"
    echo "  • Seuil noirceur (--seuil) : $SEUIL"
    echo "  • Seuil N&B (--bw-threshold) : $BW_THRESHOLD"
    echo "  • Proportion boîte (--prop) : 0.8"
    echo "  • Tolérance marques (--tol-marque) : 0.2"
    echo ""

    # Créer un dossier pour cette configuration
    TEST_DIR="tests_parametres/test${NUM}_seuil${SEUIL}_bw${BW_THRESHOLD}"
    mkdir -p "$TEST_DIR"

    # Copier les bases de données pour ce test
    cp -r data "$TEST_DIR/data_backup"

    # Supprimer les anciennes captures
    sqlite3 "$TEST_DIR/data_backup/capture.sqlite" "DELETE FROM capture_zone;" 2>/dev/null
    sqlite3 "$TEST_DIR/data_backup/capture.sqlite" "DELETE FROM capture_page;" 2>/dev/null

    echo "🔍 Analyse en cours avec ces paramètres..."

    # Lancer l'analyse avec les nouveaux paramètres
    auto-multiple-choice analyse \
        --data "$TEST_DIR/data_backup" \
        --cr "$TEST_DIR/cr" \
        --prop 0.8 \
        --bw-threshold "$BW_THRESHOLD" \
        --tol-marque 0.2 \
        --try-three \
        --debug-image-dir "$TEST_DIR/debug" \
        scans/*.png 2>&1 | grep -E "(Processing|Done|copies)" | tail -5

    echo ""

    # Recalculer les notes avec le nouveau seuil
    auto-multiple-choice note \
        --data "$TEST_DIR/data_backup" \
        --seuil "$SEUIL" \
        --grain 0.5 \
        --arrondi n >/dev/null 2>&1

    # Extraire les statistiques
    NB_COPIES=$(sqlite3 "$TEST_DIR/data_backup/capture.sqlite" "SELECT COUNT(DISTINCT student) FROM capture_page WHERE copy=0;" 2>/dev/null)

    # Calculer le score moyen et compter les copies avec score = 0
    STATS=$(sqlite3 "$TEST_DIR/data_backup/scoring.sqlite" "
        SELECT
            COUNT(DISTINCT student) as nb_students,
            AVG(total_score) as avg_score,
            MIN(total_score) as min_score,
            MAX(total_score) as max_score,
            SUM(CASE WHEN total_score = 0 THEN 1 ELSE 0 END) as nb_zero
        FROM (
            SELECT student, SUM(score) as total_score
            FROM scoring_score
            GROUP BY student
        );
    " 2>/dev/null)

    # Extraire les valeurs
    NB_STUDENTS=$(echo "$STATS" | cut -d'|' -f1)
    AVG_SCORE=$(echo "$STATS" | cut -d'|' -f2)
    MIN_SCORE=$(echo "$STATS" | cut -d'|' -f3)
    MAX_SCORE=$(echo "$STATS" | cut -d'|' -f4)
    NB_ZERO=$(echo "$STATS" | cut -d'|' -f5)

    # Calculer la note moyenne sur 20
    if [ -n "$AVG_SCORE" ]; then
        AVG_NOTE=$(echo "scale=2; ($AVG_SCORE / 44) * 20" | bc)
    else
        AVG_NOTE="N/A"
    fi

    echo "📊 RÉSULTATS :"
    echo "  • Copies analysées : $NB_COPIES"
    echo "  • Score moyen : $AVG_SCORE / 44 ($AVG_NOTE / 20)"
    echo "  • Score minimum : $MIN_SCORE"
    echo "  • Score maximum : $MAX_SCORE"
    echo "  • Copies avec 0 point : $NB_ZERO"
    echo ""

    # Vérifier les scores de Paul (21) et Rayan (28)
    PAUL_SCORE=$(sqlite3 "$TEST_DIR/data_backup/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=21;" 2>/dev/null)
    RAYAN_SCORE=$(sqlite3 "$TEST_DIR/data_backup/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=28;" 2>/dev/null)

    echo "👥 ÉLÈVES SPÉCIFIQUES (crayon léger) :"
    echo "  • Paul MEGEVAND (21) : $PAUL_SCORE / 44"
    echo "  • Rayan SOUMARE (28) : $RAYAN_SCORE / 44"
    echo ""

    # Sauvegarder un rapport
    cat > "$TEST_DIR/rapport.txt" <<EOF
TEST $NUM : $DESCRIPTION
═══════════════════════════════════════════════════════════

PARAMÈTRES :
- Seuil noirceur : $SEUIL
- Seuil N&B : $BW_THRESHOLD
- Proportion boîte : 0.8
- Tolérance marques : 0.2

RÉSULTATS :
- Copies analysées : $NB_COPIES
- Score moyen : $AVG_SCORE / 44 ($AVG_NOTE / 20)
- Score minimum : $MIN_SCORE
- Score maximum : $MAX_SCORE
- Copies avec 0 point : $NB_ZERO

ÉLÈVES SPÉCIFIQUES :
- Paul MEGEVAND (21) : $PAUL_SCORE / 44
- Rayan SOUMARE (28) : $RAYAN_SCORE / 44

Date : $(date "+%Y-%m-%d %H:%M:%S")
EOF

    echo "✅ Test terminé, résultats sauvegardés dans : $TEST_DIR"
    echo ""

    # Retourner les scores pour comparaison
    echo "$NUM|$AVG_SCORE|$NB_ZERO|$PAUL_SCORE|$RAYAN_SCORE" >> tests_parametres/comparaison.csv
}

# Créer le fichier de comparaison
echo "Test|Score_Moyen|Nb_Zeros|Paul_21|Rayan_28" > tests_parametres/comparaison.csv

# Lancer les 5 tests
test_config 1 0.03 0.15 "ACTUELS (trop sensibles)"
sleep 1

test_config 2 0.08 0.25 "CONSERVATEURS (recommandés)"
sleep 1

test_config 3 0.10 0.25 "ÉQUILIBRÉS"
sleep 1

test_config 4 0.06 0.20 "CRAYON TRÈS LÉGER"
sleep 1

test_config 5 0.12 0.30 "STYLO SEULEMENT"

# Afficher le tableau comparatif final
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TABLEAU COMPARATIF FINAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
column -t -s'|' tests_parametres/comparaison.csv
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 RECOMMANDATION :"
echo ""
echo "Choisissez la configuration qui offre :"
echo "  • Le score moyen le plus ÉLEVÉ"
echo "  • Le nombre de zéros le plus BAS"
echo "  • Les meilleurs scores pour Paul et Rayan"
echo ""
echo "Généralement, la configuration 2 ou 3 est optimale."
echo ""
echo "📁 Tous les résultats sont dans : tests_parametres/"
echo ""

read -p "Appuyez sur Entrée pour fermer..."
