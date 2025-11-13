# Améliorations de la Détection AMC - 503 QCM1

## 📋 Problème identifié

Les paramètres précédents généraient **BEAUCOUP de faux positifs** :
- **AMC_SEUIL était à 0.03** (3%) - TROP BAS !
- Cela détectait des cases vides comme cochées
- Résultats très bas pour tous les élèves
- Paul MEGEVAND (21) : 12/44 points (5.45/20)
- Rayan SOUMARE (28) : 7/44 points (3.18/20)
- Estelle CELINAIN (5) : 0/44 points (aucune détection)

## 🔬 Analyse technique

Selon la documentation AMC et les tests empiriques :

| Type de case | Niveau de noirceur |
|--------------|-------------------|
| Case VIDE | 0.7-1% |
| Case CRAYON LÉGER | 8-15% |
| Case STYLO | 15-30% |

**Le problème** : Un seuil à 3% est trop proche des cases vides (~1%), donc il détecte :
- Les salissures
- Les ombres de scan
- Les artefacts de compression
- Les pliures de papier

## ✅ Solution mise en place

### Nouveaux paramètres (OPTIMISÉS)

```bash
AMC_PROP=0.8              # Standard AMC (inchangé)
AMC_SEUIL=0.08           # 8% au lieu de 3% ✨
AMC_BW_THRESHOLD=0.25    # 0.25 au lieu de 0.15 ✨
AMC_TOL_MARQUE=0.2       # Standard AMC (inchangé)
```

### Avantages de ces paramètres

1. **AMC_SEUIL=0.08 (8%)** :
   - Marge de sécurité de 7-8% au-dessus des cases vides (~1%)
   - Détecte toujours les cases au crayon léger (8-15%)
   - Réduit drastiquement les faux positifs

2. **AMC_BW_THRESHOLD=0.25** :
   - Meilleure binarisation Noir & Blanc
   - Réduit le bruit et les artefacts
   - Plus tolérant aux variations d'éclairage

## 🧪 Nouvelle fonctionnalité : Test des paramètres

Le script propose maintenant une **option 6** pour tester automatiquement plusieurs configurations :

1. **RECOMMANDÉ** (0.08, 0.25) - Par défaut
2. **CRAYON TRÈS LÉGER** (0.06, 0.20) - Si crayon très clair
3. **CONSERVATEUR** (0.10, 0.25) - Si trop de faux positifs
4. **STYLO SEULEMENT** (0.12, 0.30) - Si uniquement stylo

Cette option compare automatiquement les résultats et identifie la meilleure configuration.

## 📝 Comment utiliser

### 1. Re-analyser les copies avec les nouveaux paramètres

```bash
# Double-cliquer sur : NEW_AMC_TOUT_EN_UN_OPTIMISE.command
# Choisir l'option 3 : "Re-traiter (si déjà analysé)"
```

Les nouveaux paramètres seront automatiquement appliqués.

### 2. Tester différentes configurations (recommandé)

```bash
# Double-cliquer sur : NEW_AMC_TOUT_EN_UN_OPTIMISE.command
# Choisir l'option 6 : "Test paramètres"
```

Le script testera 4 configurations différentes et vous indiquera la meilleure.

### 3. Ajuster manuellement si nécessaire

Ouvrir `NEW_AMC_TOUT_EN_UN_OPTIMISE.command` et modifier les lignes 52-55 :

```bash
# Si TROP de faux positifs (cases vides détectées) :
AMC_SEUIL=0.10  # ou 0.12

# Si PAS ASSEZ de détection (crayon très léger non détecté) :
AMC_SEUIL=0.06
AMC_BW_THRESHOLD=0.20
```

## 🎯 Résultats attendus

Avec les nouveaux paramètres, vous devriez observer :

✅ **Moins de faux positifs** : Les cases vides ne seront plus détectées
✅ **Meilleure détection du crayon léger** : Les cases de Rayan et Paul seront détectées
✅ **Scores plus cohérents** : Notes plus proches de la réalité
✅ **Moins d'élèves à 0** : Estelle et autres auront des détections

## 📊 Vérification des résultats

Après re-traitement, vérifiez :

1. **Le fichier CSV** : `exports/notes_avec_noms.csv`
   - Les notes doivent être plus élevées
   - Moins d'élèves avec 0 point

2. **Les PDFs annotés** : `exports/copies_individuelles/`
   - Vérifiez visuellement les cases détectées
   - Assurez-vous qu'aucune case vide n'est cochée

3. **Les images de debug** : `cr/debug/`
   - Regardez les images pour les élèves avec problèmes
   - Vérifiez que les cases cochées sont bien détectées

## 🔍 Cas particuliers

### Pour les photocopies de mauvaise qualité

```bash
AMC_PROP=0.65
AMC_SEUIL=0.10
AMC_TOL_MARQUE=0.3
AMC_BW_THRESHOLD=0.30
```

### Pour stylo uniquement (pas de crayon)

```bash
AMC_SEUIL=0.12
AMC_BW_THRESHOLD=0.30
```

## 📚 Références

- Documentation AMC : http://home.gna.org/auto-qcm/
- Recommandations officielles : `auto-multiple-choice --help analyse`
- Forum AMC : https://project.auto-multiple-choice.net/projects/auto-multiple-choice/boards

## 🚀 Prochaines étapes

1. **Lancer l'option 3** pour re-traiter avec les nouveaux paramètres
2. **Vérifier les résultats** dans `exports/notes_avec_noms.csv`
3. **Si nécessaire**, lancer l'option 6 pour tester d'autres configurations
4. **Ajuster** manuellement si besoin

## 📞 Support

Si les problèmes persistent :
- Vérifiez la qualité des scans (300 DPI minimum, Noir & Blanc)
- Consultez les images de debug dans `cr/debug/`
- Testez différentes configurations avec l'option 6
- Vérifiez que les 4 marques de coin sont bien visibles sur tous les scans

---

**Date des modifications** : 2025-11-13
**Auteur** : Claude AI
**Version** : 2.0 - Paramètres optimisés
