#!/usr/bin/env python3
"""
Trouve le seuil optimal absolu (sans comparaison avec un référence biaisée)
"""

import sqlite3
from pathlib import Path
from collections import defaultdict

# Utiliser le code du script précédent
exec(open('test_seuils_optimaux.py').read().split('def main():')[0])

def analyze_distributions(measurements):
    """Analyse la distribution des niveaux de noirceur"""
    print("📊 ANALYSE DE LA DISTRIBUTION DES NIVEAUX DE NOIRCEUR")
    print("━" * 70)
    print()

    # Grouper par étudiant
    student_darkness = defaultdict(list)
    for m in measurements:
        student_darkness[m['student']].append(m['darkness'])

    # Statistiques globales
    all_darkness = [m['darkness'] for m in measurements]
    avg_darkness = sum(all_darkness) / len(all_darkness)

    print(f"Statistiques globales (toutes les cases) :")
    print(f"  • Nombre total de cases : {len(all_darkness)}")
    print(f"  • Noirceur moyenne : {avg_darkness:.4f} ({avg_darkness*100:.2f}%)")
    print()

    # Percentiles
    sorted_darkness = sorted(all_darkness)
    p10 = sorted_darkness[int(len(sorted_darkness) * 0.10)]
    p25 = sorted_darkness[int(len(sorted_darkness) * 0.25)]
    p50 = sorted_darkness[int(len(sorted_darkness) * 0.50)]
    p75 = sorted_darkness[int(len(sorted_darkness) * 0.75)]
    p90 = sorted_darkness[int(len(sorted_darkness) * 0.90)]
    p95 = sorted_darkness[int(len(sorted_darkness) * 0.95)]
    p99 = sorted_darkness[int(len(sorted_darkness) * 0.99)]

    print("Percentiles :")
    print(f"  • 10% : {p10:.4f} ({p10*100:.2f}%)")
    print(f"  • 25% : {p25:.4f} ({p25*100:.2f}%)")
    print(f"  • 50% : {p50:.4f} ({p50*100:.2f}%)")
    print(f"  • 75% : {p75:.4f} ({p75*100:.2f}%)")
    print(f"  • 90% : {p90:.4f} ({p90*100:.2f}%)")
    print(f"  • 95% : {p95:.4f} ({p95*100:.2f}%)")
    print(f"  • 99% : {p99:.4f} ({p99*100:.2f}%)")
    print()

    # Paul et Rayan spécifiquement
    paul_dark = student_darkness[21]
    rayan_dark = student_darkness[28]

    paul_avg = sum(paul_dark) / len(paul_dark) if paul_dark else 0
    rayan_avg = sum(rayan_dark) / len(rayan_dark) if rayan_dark else 0

    print("Paul (21) et Rayan (28) :")
    print(f"  • Paul - Noirceur moyenne : {paul_avg:.4f} ({paul_avg*100:.2f}%)")
    print(f"  • Rayan - Noirceur moyenne : {rayan_avg:.4f} ({rayan_avg*100:.2f}%)")
    print()

    return p10, p25, p50, p75, p90, p95

def main():
    print()
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║   RECHERCHE DU SEUIL OPTIMAL ABSOLU                      ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print()

    capture_db = "data/capture.sqlite"
    scoring_db = "data/scoring.sqlite"

    print("📊 Chargement des données...")
    measurements = get_zone_measurements(capture_db)
    correct_answers = get_correct_answers(scoring_db)
    strategy = get_scoring_strategy(scoring_db)
    print(f"  ✓ {len(measurements)} mesures")
    print(f"  ✓ {len(correct_answers)} questions")
    print()

    # Analyser la distribution
    p10, p25, p50, p75, p90, p95 = analyze_distributions(measurements)

    print("━" * 70)
    print("💡 RECOMMANDATIONS BASÉES SUR LA DISTRIBUTION")
    print("━" * 70)
    print()
    print("Selon l'analyse de la distribution :")
    print()
    print(f"  • Seuil TRÈS BAS (détecte 95% des cases) : {p95:.3f}")
    print(f"  • Seuil BAS (détecte 90% des cases) : {p90:.3f}")
    print(f"  • Seuil MÉDIAN (détecte 75% des cases) : {p75:.3f}")
    print(f"  • Seuil STRICT (détecte 50% des cases) : {p50:.3f}")
    print()
    print("━" * 70)
    print("🔬 TEST DES SEUILS CANDIDATS")
    print("━" * 70)
    print()

    # Tester des seuils autour des percentiles critiques
    test_thresholds = [
        round(p75, 2),
        round(p90, 2),
        round(p95, 2),
        0.10, 0.15, 0.20, 0.25, 0.30
    ]
    # Dédupliquer et trier
    test_thresholds = sorted(set(test_thresholds))

    print(f"{'Seuil':>7} │ {'Paul':>5} │ {'Rayan':>6} │ {'P+R':>5} │ {'Moy':>6} │ {'Min':>5} │ {'Max':>5}")
    print("─" * 75)

    results = []
    for threshold in test_thresholds:
        scores = calculate_scores_with_threshold(measurements, correct_answers, strategy, threshold)

        paul = scores.get(21, 0)
        rayan = scores.get(28, 0)
        all_scores = list(scores.values())
        avg = sum(all_scores) / len(all_scores) if all_scores else 0
        min_score = min(all_scores) if all_scores else 0
        max_score = max(all_scores) if all_scores else 0

        results.append({
            'threshold': threshold,
            'paul': paul,
            'rayan': rayan,
            'avg': avg,
            'min': min_score,
            'max': max_score
        })

        print(f"{threshold:>7.2f} │ {paul:>5.0f} │ {rayan:>6.0f} │ {paul+rayan:>5.0f} │ {avg:>6.1f} │ {min_score:>5.0f} │ {max_score:>5.0f}")

    print()
    print("━" * 70)
    print("🎯 RECOMMANDATION FINALE")
    print("━" * 70)
    print()

    # Trouver le seuil qui donne la moyenne la plus raisonnable
    # Une moyenne autour de 50-70% (22-31/44) est normale
    best_result = None
    best_distance = 999

    target_avg = 27  # 27/44 = 61% - raisonnable pour un QCM

    for r in results:
        distance = abs(r['avg'] - target_avg)
        if distance < best_distance:
            best_distance = distance
            best_result = r

    if best_result:
        print(f"✅ SEUIL RECOMMANDÉ : {best_result['threshold']:.2f}")
        print()
        print("Ce seuil donne :")
        print(f"  • Paul (21) : {best_result['paul']:.0f} / 44")
        print(f"  • Rayan (28) : {best_result['rayan']:.0f} / 44")
        print(f"  • Moyenne classe : {best_result['avg']:.1f} / 44 ({best_result['avg']/44*100:.1f}%)")
        print(f"  • Min : {best_result['min']:.0f}, Max : {best_result['max']:.0f}")
        print()
        print("💡 Pour appliquer :")
        print("   1. Éditez NEW_AMC_TOUT_EN_UN_OPTIMISE.command")
        print(f"   2. Ligne 43 : AMC_SEUIL={best_result['threshold']:.2f}")
        print("   3. Lancez l'option 3 (Re-traiter)")
        print()

    print("━" * 70)

if __name__ == "__main__":
    main()
