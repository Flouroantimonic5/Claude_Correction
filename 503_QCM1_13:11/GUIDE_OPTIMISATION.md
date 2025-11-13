# Guide d'Optimisation - Améliorer les détections de Paul et Rayan

## 🎯 Objectif

Trouver le seuil optimal qui :
- ✅ Détecte mieux les cases au crayon léger (Paul et Rayan)
- ✅ Ne crée PAS de faux positifs pour les autres élèves
- ✅ Maintient des notes cohérentes pour la classe

---

## 📊 Situation actuelle

Avec le seuil **0.15** (standard) :
- Paul MEGEVAND (21) : Score actuel
- Rayan SOUMARE (28) : Score actuel
- Ces scores sont peut-être sous-évalués car ils écrivent au crayon léger

**Problème** : Leurs cases cochées au crayon sont peut-être trop claires et non détectées par AMC.

---

## 🔬 Solution : Test intensif de différents seuils

J'ai créé un script qui teste **11 seuils différents** :
- De **0.08** (très sensible) à **0.18** (conservateur)
- Avec un pas de **0.01**

Pour chaque seuil, le script :
1. Recalcule les notes de TOUS les élèves
2. Compare les scores de Paul et Rayan
3. Vérifie qu'il n'y a pas de faux positifs (autres élèves)
4. Identifie le seuil optimal

---

## 🚀 Comment utiliser

### Étape 1 : Lancer le script de test

```bash
# Double-cliquer sur :
test_optimisation_paul_rayan.sh

# OU dans le terminal :
cd "503_QCM1_13:11"
./test_optimisation_paul_rayan.sh
```

### Étape 2 : Attendre les résultats

Le script va :
- Tester 11 configurations (environ 2-3 minutes)
- Afficher un tableau comparatif
- Identifier le seuil optimal

### Étape 3 : Analyser les résultats

Le script génère :
- **comparaison.csv** : Tableau complet de tous les tests
- **RAPPORT_OPTIMISATION.txt** : Recommandation finale
- Un graphique texte de l'évolution des scores

### Étape 4 : Appliquer le seuil optimal

Si un seuil optimal est trouvé, éditez `NEW_AMC_TOUT_EN_UN_OPTIMISE.command` :

```bash
# Ligne 43 :
AMC_SEUIL=0.12  # Exemple : remplacer 0.15 par le seuil recommandé
```

Puis relancez l'option 3 (Re-traiter).

---

## 📖 Comprendre les résultats

### Tableau comparatif

| Seuil | Paul | Rayan | Moyenne | Delta_Autres | Gain_Paul | Gain_Rayan | Faux_Positifs |
|-------|------|-------|---------|--------------|-----------|------------|---------------|
| 0.10  | 15   | 10    | 12.5    | +3           | +3        | +3         | OUI           |
| 0.12  | 14   | 9     | 10.2    | +1           | +2        | +2         | Non           |
| 0.15  | 12   | 7     | 9.0     | 0            | 0         | 0          | baseline      |

**Colonnes :**
- **Seuil** : Le seuil de notation testé
- **Paul** : Score de Paul (21) avec ce seuil
- **Rayan** : Score de Rayan (28) avec ce seuil
- **Moyenne** : Score moyen de la classe
- **Delta_Autres** : Variation de la moyenne (détecte les faux positifs)
- **Gain_Paul/Rayan** : Points gagnés par rapport au seuil 0.15
- **Faux_Positifs** : "OUI" si augmentation suspecte de la moyenne

### Interpréter les faux positifs

**Faux positifs = OUI** signifie :
- La moyenne de la classe augmente TROP (plus de +2 points)
- Le seuil détecte probablement des cases vides comme cochées
- ❌ Ce seuil n'est PAS recommandé

**Faux positifs = Non** signifie :
- La moyenne reste stable (variation < 2 points)
- Seuls Paul et Rayan bénéficient de l'amélioration
- ✅ Ce seuil peut être utilisé

---

## 🎓 Comprendre le paramètre --seuil

### Comment fonctionne AMC ?

AMC mesure le **niveau de noirceur** de chaque case :
- 0% = Blanc pur
- 100% = Noir pur

Le paramètre `--seuil` définit le **seuil minimal** pour considérer une case comme "cochée".

### Valeurs typiques

| Seuil | Comportement | Cas d'usage |
|-------|-------------|-------------|
| **0.08** | Très sensible | Crayon TRÈS léger, risque faux positifs |
| **0.10** | Sensible | Crayon léger, quelques faux positifs possibles |
| **0.12** | Équilibré | Bon compromis crayon/stylo |
| **0.15** | **Standard** | Recommandé par AMC (défaut) |
| **0.18** | Conservateur | Stylo uniquement, ignore crayon léger |
| **0.20** | Très conservateur | Uniquement stylo foncé |

### Selon la documentation AMC

D'après la doc officielle :
- **Cases vides** : ~0.5-1% de noirceur (bruit de fond)
- **Crayon léger** : 8-15% de noirceur
- **Stylo** : 15-30% de noirceur

**Recommandation AMC** : Commencer à 0.15 et ajuster selon les résultats.

---

## ⚙️ Stratégie de test utilisée

Le script teste les seuils dans cet ordre :

1. **0.08-0.10** : Très sensible (détecte crayon très léger)
2. **0.11-0.14** : Sensible (détecte crayon léger)
3. **0.15** : Standard (référence)
4. **0.16-0.18** : Conservateur (stylo principalement)

Pour chaque seuil :
- Calcule les nouvelles notes de Paul et Rayan
- Vérifie l'impact sur les autres élèves
- Détecte les faux positifs

Le seuil optimal est celui qui :
- Maximise Paul + Rayan
- SANS créer de faux positifs (Delta_Autres < 2)

---

## 💡 Cas particuliers

### Si aucun seuil optimal n'est trouvé

Cela peut signifier :
1. **Paul et Rayan n'ont pas répondu** : Vérifiez visuellement leurs copies
2. **Leurs cases sont VRAIMENT trop claires** : Le scan n'a pas capturé le crayon
3. **Problème de qualité de scan** : Rescannez à 300 DPI minimum

**Solutions** :
- Vérifier les scans visuellement
- Augmenter la résolution du scan
- Demander à Paul et Rayan de repasser au stylo (si autorisé)

### Si le seuil optimal est très bas (0.08-0.10)

**Attention** : Cela signifie que leurs cases sont VRAIMENT très claires.

**Risques** :
- Faux positifs sur les autres copies
- Détection de salissures, ombres, etc.

**Recommandation** :
- Vérifiez MANUELLEMENT les copies des autres élèves
- Regardez dans `cr/debug/` les images de diagnostic
- Comparez visuellement avant/après

---

## 📁 Fichiers générés

Après le test, vous trouverez dans `tests_optimisation_YYYYMMDD_HHMMSS/` :

```
tests_optimisation_20251113_143022/
├── comparaison.csv                  # Tableau complet
├── RAPPORT_OPTIMISATION.txt         # Rapport final
├── scores_ref.txt                   # Scores de référence
├── data_0.08/                       # Données pour seuil 0.08
├── data_0.09/                       # Données pour seuil 0.09
├── ...
└── data_0.18/                       # Données pour seuil 0.18
```

Vous pouvez ouvrir `comparaison.csv` dans Excel pour analyser les résultats.

---

## 🔍 Vérification manuelle

Après avoir appliqué le seuil optimal, vérifiez :

### 1. Les copies de Paul et Rayan

Regardez dans `exports/copies_individuelles/` :
- `21-MEGEVAND_Paul.pdf`
- `28-SOUMARE_Rayan.pdf`

Vérifiez que les cases COCHÉES sont bien détectées (✓ vert).

### 2. Les images de diagnostic

Regardez dans `cr/debug/` :
- Trouvez les images de Paul (21) et Rayan (28)
- Vérifiez visuellement les cases détectées

### 3. Les autres élèves

Vérifiez quelques copies au hasard :
- Aucune case vide ne doit être détectée
- Les notes doivent rester cohérentes

---

## 📞 Support

Si le script ne fonctionne pas :
1. Vérifiez que vous avez bien lancé l'option 2 avant (analyse des copies)
2. Vérifiez que `data/capture.sqlite` existe
3. Consultez les logs d'erreur

Si les résultats sont incohérents :
1. Vérifiez la qualité des scans (300 DPI, N&B)
2. Vérifiez que les 4 marques de coin sont visibles
3. Vérifiez que l'impression était à 100% (pas de réduction)

---

**Date** : 2025-11-13
**Version** : 1.0
**Auteur** : Claude AI
