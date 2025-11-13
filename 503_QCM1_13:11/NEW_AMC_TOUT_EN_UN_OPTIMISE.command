#!/bin/bash

# ╔═══════════════════════════════════════════════════════════╗
# ║         AMC TOUT-EN-UN - VERSION OPTIMISÉE                ║
# ║         Paramètres recommandés par AMC                     ║
# ╚═══════════════════════════════════════════════════════════╝
#
# USAGE : Mettez dans un dossier :
#   1. Ce fichier (AMC_TOUT_EN_UN_OPTIMISE.command)
#   2. Votre fichier .tex (QCM)
#   3. Votre fichier students.csv
#
# Double-cliquez et tout se fait automatiquement !
#
# AMÉLIORATIONS :
#   ✓ Paramètres optimaux pour éviter les faux positifs
#   ✓ Validation de la qualité des scans
#   ✓ Conversion PNG optimisée (300 DPI, N&B)
#   ✓ Rapport de diagnostic détaillé
#   ✓ Gestion des photocopies
#
# ╚═══════════════════════════════════════════════════════════╝

cd "$(dirname "$0")"

clear

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         AMC TOUT-EN-UN - VERSION OPTIMISÉE                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "  Dossier : $(basename "$(pwd)")"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================
# CONFIGURATION DES PARAMÈTRES AMC
# ============================================

# Paramètres OPTIMISÉS pour détection CRAYON + STYLO
# Basés sur les recommandations officielles AMC et tests empiriques
#
# CONTEXTE :
# ✓ Cases VIDES mesurent : ~0.7-1% de noirceur
# ✓ Cases CRAYON LÉGER : 8-15% de noirceur
# ✓ Cases STYLO : 15-30% de noirceur
#
# ⚠️ IMPORTANT : Un seuil trop bas (0.03) génère BEAUCOUP de faux positifs
#    car il est trop proche des cases vides (~1%), détectant salissures et ombres

AMC_PROP=0.8              # Proportion de la boîte à mesurer (0.8 = standard AMC)
AMC_SEUIL=0.08           # Seuil de noirceur 8% (OPTIMAL : équilibre crayon léger vs faux positifs)
AMC_BW_THRESHOLD=0.25    # Seuil de binarisation N&B (0.25 = réduit le bruit et artefacts)
AMC_TOL_MARQUE=0.2       # Tolérance pour les marques de coin (0.2 = standard)

# ═══════════════════════════════════════════════════════════
# GUIDE D'AJUSTEMENT SI NÉCESSAIRE :
# ═══════════════════════════════════════════════════════════
#
# Si TROP de faux positifs (cases vides détectées) :
#   → Augmenter AMC_SEUIL à 0.10 ou 0.12
#
# Si PAS ASSEZ de détection (crayon très léger non détecté) :
#   → Réduire AMC_SEUIL à 0.06
#   → Réduire AMC_BW_THRESHOLD à 0.20
#
# Pour PHOTOCOPIES de mauvaise qualité :
#   → AMC_PROP=0.65
#   → AMC_SEUIL=0.10
#   → AMC_TOL_MARQUE=0.3
#   → AMC_BW_THRESHOLD=0.30
#
# Pour STYLO UNIQUEMENT (pas de crayon) :
#   → AMC_SEUIL=0.12
#   → AMC_BW_THRESHOLD=0.30
#
# ═══════════════════════════════════════════════════════════

# ============================================
# DÉTECTION AUTOMATIQUE DES FICHIERS
# ============================================

echo "🔍 Détection des fichiers..."
echo ""

# Trouver le fichier .tex
TEX_FILE=$(find . -maxdepth 1 -name "*.tex" -not -name "amc-compiled*" -not -name "DOC-*" | head -1)
if [ -z "$TEX_FILE" ]; then
    echo "❌ ERREUR : Aucun fichier .tex trouvé"
    echo ""
    echo "📝 Créez un fichier .tex dans ce dossier"
    echo ""
    read -p "Appuyez sur Entrée pour fermer..."
    exit 1
fi
TEX_FILE=$(basename "$TEX_FILE")
echo "  ✓ Fichier LaTeX : $TEX_FILE"

# Trouver le fichier students.csv
if [ ! -f "students.csv" ]; then
    echo "❌ ERREUR : students.csv introuvable"
    echo ""
    echo "📝 Créez students.csv avec :"
    echo "   nom,prenom,numero"
    echo "   DUPONT,Jean,1"
    echo "   MARTIN,Marie,2"
    echo ""
    read -p "Appuyez sur Entrée pour fermer..."
    exit 1
fi
echo "  ✓ Liste élèves : students.csv"

# Compter les élèves
NB_ELEVES=$(tail -n +2 students.csv | wc -l | tr -d ' ')
echo "  ✓ Nombre d'élèves : $NB_ELEVES"
echo ""

# ============================================
# MENU PRINCIPAL
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 QUE VOULEZ-VOUS FAIRE ?"
echo ""
echo "  1) 📄 Compiler et imprimer les copies"
echo "  2) 📸 Analyser les scans → Résultats complets"
echo "  3) 🚀 Re-traiter (si déjà analysé)"
echo "  4) ⚡ TOUT FAIRE (1+2 en continu)"
echo "  5) 🔧 Diagnostic qualité des scans"
echo "  6) 🧪 Test paramètres (trouver configuration optimale)"
echo ""
echo "  0) Quitter"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Paramètres actuels : SEUIL=$AMC_SEUIL, BW_THRESHOLD=$AMC_BW_THRESHOLD"
echo ""
read -p "Votre choix (1/2/3/4/5/6/0) : " choix
echo ""

case $choix in

# ============================================
# OPTION 1 : COMPILATION + IMPRESSION
# ============================================
1|4)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 ÉTAPE 1 : COMPILATION DU SUJET"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Créer la structure AMC si nécessaire
    mkdir -p data scans exports cr

    echo "🔨 Compilation LaTeX avec AMC..."
    echo ""

    # Compiler avec AMC
    auto-multiple-choice prepare \
        --mode s \
        --prefix amc-compiled \
        --data data \
        --latex-stdout \
        "$TEX_FILE" 2>&1 | tail -20

    # AMC génère : amc-compiledsujet.pdf (tout attaché)
    if [ ! -f "amc-compiledsujet.pdf" ]; then
        echo ""
        echo "❌ Erreur lors de la compilation"
        echo "   Vérifiez votre fichier $TEX_FILE"
        echo ""
        echo "Fichiers générés :"
        ls -lh amc-compiled*.pdf 2>/dev/null
        echo ""
        read -p "Appuyez sur Entrée pour fermer..."
        exit 1
    fi

    echo ""
    echo "✅ Compilation réussie : amc-compiledsujet.pdf"
    echo ""

    # Générer le layout (obligatoire pour l'analyse)
    echo "🗺️  Génération du layout..."
    auto-multiple-choice meptex --src amc-compiledcalage.xy --data data >/dev/null 2>&1
    echo "  ✓ Layout généré"
    echo ""

    # Copier en DOC-sujet.pdf pour compatibilité
    cp amc-compiledsujet.pdf DOC-sujet.pdf

    # Variable pour la suite
    SUJET_PDF="DOC-sujet.pdf"

    echo "📄 Le sujet a été généré pour $NB_ELEVES élèves"
    echo "   → $(ls -lh DOC-sujet.pdf | awk '{print $5}')"
    echo ""

    # Ouvrir le PDF
    echo "📖 Ouverture du PDF..."
    open DOC-sujet.pdf 2>/dev/null

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🖨️  IMPRESSION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⚠️  IMPORTANT - Paramètres d'impression :"
    echo "   → 1 copie par élève ($NB_ELEVES copies)"
    echo "   → Échelle : 100% (PAS de réduction/agrandissement)"
    echo "   → Recto-verso si possible"
    echo "   → Mode : Normal (pas de brouillon)"
    echo ""
    echo "💡 CONSEIL : Imprimez 2-3 copies de test et scannez-les"
    echo "            pour vérifier la détection avant l'examen"
    echo ""

    if [ "$choix" = "1" ]; then
        read -p "✅ Appuyez sur Entrée pour fermer..."
        osascript -e 'tell application "Terminal" to close first window' > /dev/null 2>&1
        sleep 0.1
        exit 0
    fi

    # Si choix = 4, continuer vers l'étape 2
    if [ "$choix" = "4" ]; then
        read -p "Appuyez sur Entrée pour continuer vers le scan..."
        echo ""
    fi
    ;;

esac

# ============================================
# FONCTION : VALIDATION QUALITÉ DES SCANS
# ============================================
validate_scan_quality() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 VALIDATION QUALITÉ DES SCANS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    QUALITY_OK=true
    WARNINGS=0

    # Vérifier chaque PNG
    for img in scans/*.png; do
        if [ -f "$img" ]; then
            filename=$(basename "$img")

            # Vérifier la résolution avec identify (ImageMagick)
            if command -v identify >/dev/null 2>&1; then
                resolution=$(identify -format "%x %y" "$img" 2>/dev/null | awk '{print $1}')
                width=$(identify -format "%w" "$img" 2>/dev/null)
                height=$(identify -format "%h" "$img" 2>/dev/null)

                # Convertir la résolution en DPI (si en PixelsPerCentimeter)
                if [ -n "$resolution" ]; then
                    dpi=$(echo "$resolution" | awk '{print int($1 * 2.54)}')

                    if [ "$dpi" -lt 200 ]; then
                        echo "  ⚠️  $filename : Résolution faible ($dpi DPI)"
                        echo "      → Recommandé : 300 DPI minimum"
                        QUALITY_OK=false
                        WARNINGS=$((WARNINGS + 1))
                    else
                        echo "  ✓ $filename : ${dpi} DPI, ${width}x${height}px"
                    fi
                fi
            fi

            # Vérifier la taille du fichier
            filesize=$(stat -f%z "$img" 2>/dev/null || stat -c%s "$img" 2>/dev/null)
            if [ "$filesize" -lt 100000 ]; then
                echo "  ⚠️  $filename : Fichier très petit ($filesize octets)"
                echo "      → Possible problème de qualité"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    done

    echo ""
    if [ "$QUALITY_OK" = false ]; then
        echo "⚠️  ATTENTION : $WARNINGS avertissement(s) de qualité détecté(s)"
        echo ""
        echo "Recommandations :"
        echo "  • Scannez à 300 DPI minimum"
        echo "  • Utilisez le mode 'Noir et Blanc' (pas niveaux de gris)"
        echo "  • Évitez les compressions JPG"
        echo ""
        read -p "Continuer malgré les avertissements ? (o/n) " continue_anyway
        if [ "$continue_anyway" != "o" ]; then
            echo "Arrêt du traitement."
            exit 1
        fi
    else
        echo "✅ Qualité des scans validée"
    fi
    echo ""
}

# ============================================
# OPTION 5 : DIAGNOSTIC QUALITÉ
# ============================================
if [ "$choix" = "5" ]; then
    if [ ! -d "scans" ] || [ $(ls -1 scans/*.png 2>/dev/null | wc -l) -eq 0 ]; then
        echo "❌ Aucun scan PNG trouvé dans scans/"
        read -p "Appuyez sur Entrée pour fermer..."
        exit 1
    fi

    validate_scan_quality

    read -p "✅ Diagnostic terminé. Appuyez sur Entrée pour fermer..."
    exit 0
fi

# ============================================
# OPTION 2 : SCAN + ANALYSE
# ============================================
if [ "$choix" = "2" ] || [ "$choix" = "4" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📸 ÉTAPE 2 : SCAN ET ANALYSE DES COPIES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    mkdir -p scans cr

    # Vérifier les scans
    NB_SCANS=$(ls -1 scans/*.pdf scans/*.png scans/*.jpg 2>/dev/null | wc -l | tr -d ' ')
    NB_SCANS=${NB_SCANS:-0}  # Défaut à 0 si vide

    if [ "$NB_SCANS" -eq 0 ]; then
        echo "⚠️  Aucun scan trouvé dans scans/"
        echo ""
        echo "📸 Scannez vos copies avec les paramètres suivants :"
        echo "   ► Résolution : 300 DPI"
        echo "   ► Mode : Noir et Blanc (pas niveaux de gris)"
        echo "   ► Format : PNG ou PDF"
        echo "   ► Compression : Aucune"
        echo ""
        echo "Options :"
        echo "  • Scannez avec votre scanner → scans/"
        echo "  • Utilisez une app mobile → scans/"
        echo "  • Ou ouvrez AMC pour scanner"
        echo ""
        read -p "Voulez-vous ouvrir AMC pour scanner ? (o/n) " open_amc

        if [ "$open_amc" = "o" ]; then
            echo ""
            echo "🚀 Ouverture d'AMC..."
            echo ""
            echo "Dans AMC :"
            echo "  1. Fichier → Ouvrir un projet"
            echo "  2. Sélectionner ce dossier : $(pwd)"
            echo "  3. Onglet 'Scan' → Scanner vos copies"
            echo "  4. Onglet 'Notation' → Analyser les copies"
            echo "  5. FERMER AMC"
            echo "  6. Relancer ce script"
            echo ""

            auto-multiple-choice &

            read -p "Appuyez sur Entrée quand vous avez fini dans AMC..."
            exit 0
        else
            echo ""
            read -p "Scannez vos copies et relancez ce script. Entrée pour fermer..."
            exit 0
        fi
    fi

    echo "  ✓ Scans détectés : $NB_SCANS fichiers"
    echo ""

    # ──────────────────────────────────────────
    # CONVERSION PDF → PNG OPTIMISÉE
    # ──────────────────────────────────────────
    if ls scans/*.pdf >/dev/null 2>&1; then
        echo "📄→🖼️  Conversion PDF → PNG optimisée (300 DPI, N&B)..."
        echo ""
        for pdf in scans/*.pdf; do
            if [ -f "$pdf" ]; then
                basename_pdf=$(basename "$pdf" .pdf)
                echo "  • Conversion de $basename_pdf.pdf..."

                # Conversion optimisée avec pdftoppm
                # -r 300 : 300 DPI
                # -png : Format PNG
                # -mono : Noir et Blanc (recommandé par AMC)
                pdftoppm -png -r 300 -mono "$pdf" "scans/${basename_pdf}" >/dev/null 2>&1

                if [ $? -eq 0 ]; then
                    rm "$pdf"  # Supprimer le PDF après conversion réussie
                    echo "    ✓ Converti en N&B 300 DPI"
                else
                    echo "    ⚠️  Erreur de conversion, utilisation du PDF original"
                fi
            fi
        done
        echo ""
    fi

    # ──────────────────────────────────────────
    # VALIDATION QUALITÉ
    # ──────────────────────────────────────────
    validate_scan_quality

    # ──────────────────────────────────────────
    # ANALYSE AVEC PARAMÈTRES OPTIMAUX
    # ──────────────────────────────────────────
    echo "🔍 Analyse automatique des copies avec paramètres optimaux..."
    echo ""
    echo "Paramètres utilisés :"
    echo "  • Proportion boîte (--prop) : $AMC_PROP"
    echo "  • Seuil noirceur (--seuil) : $AMC_SEUIL"
    echo "  • Seuil N&B (--bw-threshold) : $AMC_BW_THRESHOLD"
    echo "  • Tolérance marques (--tol-marque) : $AMC_TOL_MARQUE"
    echo ""

    # Analyser les scans avec TOUS les paramètres optimaux
    auto-multiple-choice analyse \
        --data data \
        --cr cr \
        --prop "$AMC_PROP" \
        --bw-threshold "$AMC_BW_THRESHOLD" \
        --tol-marque "$AMC_TOL_MARQUE" \
        --try-three \
        --debug-image-dir cr/debug \
        scans/*.png scans/*.jpg 2>&1 | tee /tmp/amc_analyse.log | grep -E "(Processing|Analyzing|Done|copies|page)" | tail -15

    echo ""

    # ──────────────────────────────────────────
    # VÉRIFICATION ET RAPPORT DIAGNOSTIC
    # ──────────────────────────────────────────
    NB_COPIES=$(sqlite3 "data/capture.sqlite" "SELECT COUNT(DISTINCT student) FROM capture_page WHERE copy=0;" 2>/dev/null)
    NB_COPIES=${NB_COPIES:-0}  # Défaut à 0 si vide

    if [ "$NB_COPIES" -gt 0 ]; then
        echo "✅ $NB_COPIES copies analysées"

        # Générer un rapport de diagnostic
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 RAPPORT DIAGNOSTIC"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Vérifier les erreurs potentielles
        if [ -f "/tmp/amc_analyse.log" ]; then
            nb_warnings=$(grep -i "warning" /tmp/amc_analyse.log | wc -l | tr -d ' ')
            nb_errors=$(grep -i "error" /tmp/amc_analyse.log | wc -l | tr -d ' ')

            if [ "$nb_warnings" -gt 0 ]; then
                echo "⚠️  Avertissements détectés : $nb_warnings"
                echo "    Consultez cr/debug/ pour les images de diagnostic"
                echo ""
            fi

            if [ "$nb_errors" -gt 0 ]; then
                echo "❌ Erreurs détectées : $nb_errors"
                echo ""
                echo "Solutions possibles :"
                echo "  1. Vérifiez que les 4 marques de coin sont visibles"
                echo "  2. Vérifiez l'échelle d'impression (doit être 100%)"
                echo "  3. Augmentez --tol-marque à 0.3 (photocopies)"
                echo "  4. Consultez les logs : /tmp/amc_analyse.log"
                echo ""
            fi
        fi

        # Statistiques sur les pages
        nb_pages=$(sqlite3 "data/capture.sqlite" "SELECT COUNT(*) FROM capture_page WHERE copy=0;" 2>/dev/null)
        echo "Pages analysées : $nb_pages"

        # Vérifier s'il y a des copies avec problèmes
        nb_problematic=$(sqlite3 "data/capture.sqlite" "SELECT COUNT(DISTINCT student) FROM capture_page WHERE timestamp_auto=0 AND copy=0;" 2>/dev/null)
        if [ "$nb_problematic" -gt 0 ]; then
            echo ""
            echo "⚠️  Copies avec problèmes potentiels : $nb_problematic"
            echo "    → Vérifiez manuellement dans AMC (onglet 'Saisie')"
        fi

        echo ""
        echo "💡 Images de diagnostic disponibles dans : cr/debug/"
        echo "   Consultez-les si vous avez des doutes sur la détection"
        echo ""

    else
        echo "❌ Aucune copie analysée"
        echo ""
        echo "🔧 DÉPANNAGE :"
        echo ""
        echo "1. Vérifiez que le layout a été généré :"
        echo "   → Dossier data/ doit contenir layout.xml"
        echo ""
        echo "2. Vérifiez vos scans :"
        echo "   → 4 marques de coin visibles"
        echo "   → Impression à 100% (pas de réduction)"
        echo "   → Images en N&B 300 DPI"
        echo ""
        echo "3. Consultez les logs : /tmp/amc_analyse.log"
        echo ""
        echo "4. Si photocopies, modifiez les paramètres en haut du script :"
        echo "   AMC_PROP=0.65"
        echo "   AMC_TOL_MARQUE=0.3"
        echo ""
        read -p "Appuyez sur Entrée pour fermer..."
        exit 1
    fi

    echo ""

    # Si choix = 2 ou 4, continuer automatiquement vers l'étape 3
    if [ "$choix" = "2" ] || [ "$choix" = "4" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "▶️  Passage automatique au traitement..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        sleep 1
    fi
fi

# ============================================
# OPTION 3 : TRAITEMENT AUTOMATIQUE
# ============================================
if [ "$choix" = "2" ] || [ "$choix" = "3" ] || [ "$choix" = "4" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 ÉTAPE 3 : TRAITEMENT AUTOMATIQUE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Vérifier que l'analyse a été faite
    if [ ! -f "data/capture.sqlite" ]; then
        echo "❌ Les copies n'ont pas été analysées"
        echo "   Faites d'abord l'option 1 et 2"
        read -p "Appuyez sur Entrée pour fermer..."
        exit 1
    fi

    NB_COPIES=$(sqlite3 "data/capture.sqlite" "SELECT COUNT(DISTINCT student) FROM capture_page WHERE copy=0;" 2>/dev/null)
    NB_COPIES=${NB_COPIES:-0}  # Défaut à 0 si vide

    if [ "$NB_COPIES" -eq 0 ]; then
        echo "❌ Aucune copie trouvée"
        read -p "Appuyez sur Entrée pour fermer..."
        exit 1
    fi

    echo "📋 Copies à traiter : $NB_COPIES"
    echo ""

    # ──────────────────────────────────────────
    # 3.1 - ASSOCIATIONS
    # ──────────────────────────────────────────
    echo "🔗 3.1 - Associations copies → élèves"

    DB_ASSOC="data/association.sqlite"
    # Créer la table si elle n'existe pas
    sqlite3 "$DB_ASSOC" "CREATE TABLE IF NOT EXISTS association_association (student INTEGER, copy INTEGER, manual TEXT, auto TEXT, PRIMARY KEY (student, copy));" 2>/dev/null
    sqlite3 "$DB_ASSOC" "DELETE FROM association_association;" 2>/dev/null

    counter=0
    tail -n +2 students.csv | while IFS=',' read -r nom prenom numero; do
        counter=$((counter + 1))
        if [ $counter -le $NB_COPIES ]; then
            sqlite3 "$DB_ASSOC" "INSERT OR REPLACE INTO association_association (student, copy, manual, auto) VALUES ($counter, 0, '$numero', '');" 2>/dev/null
            echo "  ✓ $counter. $prenom $nom"
        fi
    done

    sqlite3 "$DB_ASSOC" "UPDATE association_association SET manual = REPLACE(manual, char(13), '');" 2>/dev/null
    echo ""

    # ──────────────────────────────────────────
    # 3.2 - NOTATION AVEC SEUIL OPTIMAL
    # ──────────────────────────────────────────
    echo "📊 3.2 - Calcul des notes"

    # D'abord préparer le barème (copier layout vers scoring)
    if [ ! -f "$TEX_FILE" ]; then
        TEX_FILE=$(find . -maxdepth 1 -name "*.tex" -not -name "amc-compiled*" -not -name "DOC-*" | head -1)
        TEX_FILE=$(basename "$TEX_FILE")
    fi

    auto-multiple-choice prepare \
        --mode b \
        --data data \
        --progression-id note \
        --progression 1 \
        --n-copies 0 \
        "$TEX_FILE" >/dev/null 2>&1

    # Puis calculer les notes avec le seuil configuré
    auto-multiple-choice note \
        --data data \
        --seuil "$AMC_SEUIL" \
        --grain 0.5 \
        --arrondi n 2>&1 | grep -v "SQL" | tail -5

    echo "  ✅ Notes calculées (seuil : $AMC_SEUIL)"
    echo ""

    # ──────────────────────────────────────────
    # 3.3 - EXPORT CSV
    # ──────────────────────────────────────────
    echo "📄 3.3 - Export CSV avec noms"

    mkdir -p exports

    python3 << 'PYTHON_SCRIPT'
import sqlite3
import csv
import sys

try:
    conn_assoc = sqlite3.connect('data/association.sqlite')
    conn_scoring = sqlite3.connect('data/scoring.sqlite')

    students = {}
    with open('students.csv', 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            numero = row['numero']
            students[numero] = {'nom': row['nom'], 'prenom': row['prenom'], 'numero': numero}

    associations = {}
    cursor = conn_assoc.cursor()
    cursor.execute("SELECT student, manual FROM association_association")
    for row in cursor:
        if row[1]:
            associations[row[0]] = row[1].strip()

    cursor_scoring = conn_scoring.cursor()
    cursor_scoring.execute("SELECT student, question, score FROM scoring_score ORDER BY student, question")

    student_scores = {}
    for row in cursor_scoring:
        student_id, question, score = row
        if student_id not in student_scores:
            student_scores[student_id] = {}
        student_scores[student_id][question] = score

    # Calculer le nombre maximum de questions
    max_questions = 0
    if student_scores:
        for scores in student_scores.values():
            if scores:
                max_q = max(scores.keys())
                max_questions = max(max_questions, max_q)

    output_rows = []
    for student_id in sorted(student_scores.keys()):
        numero = associations.get(student_id, '?')
        student_info = students.get(numero, {'nom': '?', 'prenom': '?', 'numero': numero})

        total = sum(student_scores[student_id].values())
        # Ramener la note sur 20 sans arrondi
        if max_questions > 0:
            note_sur_20 = (total / max_questions) * 20
        else:
            note_sur_20 = 0

        row = {
            'Exam': student_id,
            'Numero': numero,
            'Nom': student_info['nom'],
            'Prenom': student_info['prenom'],
            'Note totale': total,
            'Note': f"{note_sur_20:.2f}".replace('.', ','),
        }

        if student_scores[student_id]:
            max_q = max(student_scores[student_id].keys())
            for q in range(1, max_q + 1):
                score = student_scores[student_id].get(q, 0)
                row[f'q{q:02d}'] = int(score)

        output_rows.append(row)

    if output_rows and student_scores:
        max_q = max([max(s.keys()) for s in student_scores.values() if s])
        fieldnames = ['Exam', 'Numero', 'Nom', 'Prenom', 'Note totale', 'Note'] + [f'q{i:02d}' for i in range(1, max_q + 1)]
    else:
        fieldnames = ['Exam', 'Numero', 'Nom', 'Prenom', 'Note totale', 'Note']

    with open('exports/notes_avec_noms.csv', 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(output_rows)

    print(f"  ✅ CSV créé : {len(output_rows)} étudiants")

    conn_assoc.close()
    conn_scoring.close()
except Exception as e:
    print(f"  ❌ Erreur : {e}")
    sys.exit(1)
PYTHON_SCRIPT

    echo ""

    # ──────────────────────────────────────────
    # 3.4 - PDFs ANNOTÉS
    # ──────────────────────────────────────────
    echo "📑 3.4 - PDFs annotés individuels"

    # Créer le dossier de corrections
    mkdir -p cr/corrections/pdf

    # Trouver le fichier sujet
    if [ -f "DOC-sujet.pdf" ]; then
        SUJET="DOC-sujet.pdf"
    elif [ -f "amc-compiledsujet.pdf" ]; then
        SUJET="amc-compiledsujet.pdf"
    else
        echo "  ⚠️  Fichier sujet introuvable"
        SUJET=""
    fi

    if [ -n "$SUJET" ]; then
        rm -f cr/corrections/pdf/*.pdf 2>/dev/null

        # Utiliser la base d'association pour les noms
        auto-multiple-choice annotate \
            --project . \
            --data data \
            --names-file students.csv \
            --subject "$SUJET" 2>&1 | grep -v "WARNING" | grep -v "uninitialized"

        mkdir -p exports/copies_individuelles
        rm -f exports/copies_individuelles/*.pdf
        cp cr/corrections/pdf/*.pdf exports/copies_individuelles/ 2>/dev/null

        nb_pdf=$(ls -1 exports/copies_individuelles/*.pdf 2>/dev/null | wc -l | tr -d ' ')
        nb_pdf=${nb_pdf:-0}  # Défaut à 0 si vide

        # Renommer les PDFs avec les noms des élèves
        if [ $nb_pdf -gt 0 ]; then
            echo "  🏷️  Renommage avec les noms des élèves..."
            python3 << 'RENAME_SCRIPT'
import csv
import os
import shutil

students = {}
with open('students.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        numero = int(row['numero'])
        nom = row['nom'].replace(' ', '_').replace('/', '_')
        prenom = row['prenom'].replace(' ', '_').replace('/', '_')
        students[numero] = f"{nom}_{prenom}"

pdf_dir = 'exports/copies_individuelles'
for pdf_file in os.listdir(pdf_dir):
    if pdf_file.endswith('.pdf') and '_ID_' in pdf_file:
        student_num = int(pdf_file.split('-')[0])
        if student_num in students:
            new_name = f"{pdf_file.split('-')[0]}-{students[student_num]}.pdf"
            shutil.move(os.path.join(pdf_dir, pdf_file), os.path.join(pdf_dir, new_name))
RENAME_SCRIPT
        fi

        echo "  ✅ $nb_pdf PDFs générés avec noms"
    else
        echo "  ⚠️  PDFs non générés (sujet manquant)"
        nb_pdf=0
    fi

    echo ""

    # ──────────────────────────────────────────
    # RAPPORT FINAL DÉTAILLÉ
    # ──────────────────────────────────────────
    cat > exports/RAPPORT.txt <<EOF
═══════════════════════════════════════════════════════════
RAPPORT AMC - VERSION OPTIMISÉE
═══════════════════════════════════════════════════════════

Date : $(date "+%Y-%m-%d %H:%M:%S")
Projet : $(basename "$(pwd)")
Fichier : $TEX_FILE

✅ RÉSULTATS :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Élèves dans CSV : $NB_ELEVES
Copies analysées : $NB_COPIES
PDFs générés : $nb_pdf

⚙️  PARAMÈTRES UTILISÉS :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Proportion boîte (--prop) : $AMC_PROP
Seuil noirceur (--seuil) : $AMC_SEUIL
Seuil N&B (--bw-threshold) : $AMC_BW_THRESHOLD
Tolérance marques (--tol-marque) : $AMC_TOL_MARQUE

📂 FICHIERS GÉNÉRÉS :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ exports/notes_avec_noms.csv
  → Fichier Excel avec noms et notes détaillées

✓ exports/copies_individuelles/
  → $nb_pdf PDFs annotés avec corrections

✓ cr/debug/
  → Images de diagnostic pour vérification

═══════════════════════════════════════════════════════════
EOF

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    cat exports/RAPPORT.txt
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 TRAITEMENT TERMINÉ !"
    echo ""
    echo "📁 Résultats dans : exports/"
    echo "🔍 Images diagnostic : cr/debug/"
    echo ""

    # Ouvrir le dossier exports
    open exports/ 2>/dev/null || xdg-open exports/ 2>/dev/null

    if [ "$choix" = "4" ]; then
        echo "✅ TOUT EST FAIT !"
        echo ""
        echo "De la compilation à l'export, tout a été automatisé ✨"
        echo ""
    fi

    if [ "$choix" = "2" ]; then
        read -p "✅ Appuyez sur Entrée pour fermer..."
        osascript -e 'tell application "Terminal" to close first window' > /dev/null 2>&1
        sleep 0.1
        exit 0
    fi

    read -p "Appuyez sur Entrée pour fermer..."
fi

# ============================================
# OPTION 6 : TEST DES PARAMÈTRES
# ============================================
if [ "$choix" = "6" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 TEST DES PARAMÈTRES AMC"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Cette option va tester plusieurs configurations de paramètres"
    echo "pour trouver celle qui donne les meilleurs résultats."
    echo ""
    echo "⚠️  ATTENTION : Cela peut prendre plusieurs minutes"
    echo ""

    # Vérifier que les données de base existent
    if [ ! -f "data/layout.sqlite" ]; then
        echo "❌ Erreur : Le layout n'a pas été généré"
        echo "   Lancez d'abord l'option 1"
        read -p "Appuyez sur Entrée pour fermer..."
        exit 1
    fi

    if [ ! -d "scans" ] || [ $(ls -1 scans/*.png 2>/dev/null | wc -l) -eq 0 ]; then
        echo "❌ Erreur : Aucun scan trouvé dans scans/"
        read -p "Appuyez sur Entrée pour fermer..."
        exit 1
    fi

    read -p "Voulez-vous continuer ? (o/n) " continue_test
    if [ "$continue_test" != "o" ]; then
        echo "Test annulé."
        exit 0
    fi

    echo ""
    echo "🔄 Lancement des tests..."
    echo ""

    # Créer un dossier de test
    mkdir -p tests_parametres

    # Définir les configurations à tester
    declare -a CONFIGS=(
        "0.08|0.25|RECOMMANDÉ (optimal)"
        "0.06|0.20|CRAYON TRÈS LÉGER"
        "0.10|0.25|CONSERVATEUR"
        "0.12|0.30|STYLO SEULEMENT"
    )

    BEST_CONFIG=""
    BEST_AVG_SCORE=0
    CONFIG_NUM=1

    for config in "${CONFIGS[@]}"; do
        SEUIL=$(echo "$config" | cut -d'|' -f1)
        BW=$(echo "$config" | cut -d'|' -f2)
        DESC=$(echo "$config" | cut -d'|' -f3)

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "TEST $CONFIG_NUM : $DESC"
        echo "  Seuil=$SEUIL, BW_Threshold=$BW"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Créer un dossier pour ce test
        TEST_DIR="tests_parametres/test${CONFIG_NUM}_${DESC// /_}"
        mkdir -p "$TEST_DIR"

        # Copier les bases de données
        cp -r data "$TEST_DIR/data_test"

        # Réinitialiser les captures
        rm -f "$TEST_DIR/data_test/capture.sqlite" 2>/dev/null
        cp data/capture.sqlite "$TEST_DIR/data_test/" 2>/dev/null

        # Analyser avec ces paramètres
        echo "🔍 Analyse en cours..."
        auto-multiple-choice analyse \
            --data "$TEST_DIR/data_test" \
            --cr "$TEST_DIR/cr" \
            --prop 0.8 \
            --bw-threshold "$BW" \
            --tol-marque 0.2 \
            --try-three \
            scans/*.png 2>&1 | grep -E "(Processing|Done)" | tail -3

        # Recalculer les notes
        auto-multiple-choice note \
            --data "$TEST_DIR/data_test" \
            --seuil "$SEUIL" \
            --grain 0.5 \
            --arrondi n >/dev/null 2>&1

        # Extraire les statistiques
        STATS=$(sqlite3 "$TEST_DIR/data_test/scoring.sqlite" "
            SELECT AVG(total), MIN(total), MAX(total), COUNT(*)
            FROM (SELECT student, SUM(score) as total FROM scoring_score GROUP BY student);
        " 2>/dev/null)

        AVG=$(echo "$STATS" | cut -d'|' -f1 | cut -d'.' -f1)
        MIN=$(echo "$STATS" | cut -d'|' -f2 | cut -d'.' -f1)
        MAX=$(echo "$STATS" | cut -d'|' -f3 | cut -d'.' -f1)

        echo "📊 Score moyen : $AVG/44  (min=$MIN, max=$MAX)"

        # Vérifier Paul et Rayan
        PAUL=$(sqlite3 "$TEST_DIR/data_test/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=21;" 2>/dev/null | cut -d'.' -f1)
        RAYAN=$(sqlite3 "$TEST_DIR/data_test/scoring.sqlite" "SELECT SUM(score) FROM scoring_score WHERE student=28;" 2>/dev/null | cut -d'.' -f1)

        echo "👥 Paul (21): $PAUL/44  |  Rayan (28): $RAYAN/44"
        echo ""

        # Garder la meilleure config
        if [ "$AVG" -gt "$BEST_AVG_SCORE" ]; then
            BEST_AVG_SCORE=$AVG
            BEST_CONFIG="$DESC (Seuil=$SEUIL, BW=$BW)"
        fi

        CONFIG_NUM=$((CONFIG_NUM + 1))
        sleep 1
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ TESTS TERMINÉS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🏆 MEILLEURE CONFIGURATION : $BEST_CONFIG"
    echo "   Score moyen : $BEST_AVG_SCORE/44"
    echo ""
    echo "📁 Résultats détaillés dans : tests_parametres/"
    echo ""
    read -p "Appuyez sur Entrée pour fermer..."
    exit 0
fi

if [ "$choix" = "0" ]; then
    echo "Au revoir !"
    exit 0
fi

if [ "$choix" != "1" ] && [ "$choix" != "2" ] && [ "$choix" != "3" ] && [ "$choix" != "4" ] && [ "$choix" != "5" ] && [ "$choix" != "6" ] && [ "$choix" != "0" ]; then
    echo "❌ Choix invalide"
    read -p "Appuyez sur Entrée pour fermer..."
    exit 1
fi
