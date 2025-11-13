#!/usr/bin/env python3
"""
Script d'analyse des seuils optimaux pour AMC
Teste différents seuils pour trouver celui qui maximise Paul et Rayan
sans créer de faux positifs
"""

import sqlite3
import sys
from pathlib import Path

def get_current_scores(db_path):
    """Récupère les scores actuels depuis scoring.sqlite"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Scores par étudiant
    cursor.execute("""
        SELECT student, SUM(score) as total
        FROM scoring_score
        GROUP BY student
        ORDER BY student
    """)

    scores = {}
    for row in cursor.fetchall():
        student_id, total = row
        scores[student_id] = total

    conn.close()
    return scores

def get_zone_measurements(db_path):
    """Récupère toutes les mesures de noirceur depuis capture.sqlite"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Récupérer toutes les zones (cases) avec leur niveau de noirceur
    cursor.execute("""
        SELECT student, copy, page, question, answer, total, black
        FROM capture_zone
        WHERE copy = 0
        ORDER BY student, question, answer
    """)

    measurements = []
    for row in cursor.fetchall():
        student, copy, page, question, answer, total, black = row
        if total > 0:
            darkness = black / total  # Niveau de noirceur (0-1)
        else:
            darkness = 0

        measurements.append({
            'student': student,
            'question': question,
            'answer': answer,
            'darkness': darkness,
            'black': black,
            'total': total
        })

    conn.close()
    return measurements

def get_correct_answers(db_path):
    """Récupère les bonnes réponses depuis scoring.sqlite"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Récupérer les bonnes réponses
    cursor.execute("""
        SELECT question, answer
        FROM scoring_answer
        WHERE correct = 1
    """)

    correct = {}
    for row in cursor.fetchall():
        question, answer = row
        if question not in correct:
            correct[question] = []
        correct[question].append(answer)

    conn.close()
    return correct

def calculate_scores_with_threshold(measurements, correct_answers, threshold):
    """Calcule les scores avec un seuil donné"""
    # Grouper par étudiant et question
    student_responses = {}

    for m in measurements:
        student = m['student']
        question = m['question']
        answer = m['answer']
        darkness = m['darkness']

        if student not in student_responses:
            student_responses[student] = {}

        if question not in student_responses[student]:
            student_responses[student][question] = []

        # Si la case est cochée (darkness > threshold)
        if darkness >= threshold:
            student_responses[student][question].append(answer)

    # Calculer les scores
    scores = {}
    for student in student_responses:
        scores[student] = 0
        for question in student_responses[student]:
            checked = student_responses[student][question]
            correct = correct_answers.get(question, [])

            # Score : 1 si réponse correcte et unique, 0 sinon
            if len(checked) == 1 and checked[0] in correct:
                scores[student] += 1

    return scores

def test_threshold(threshold, measurements, correct_answers, ref_scores):
    """Teste un seuil et retourne les résultats"""
    scores = calculate_scores_with_threshold(measurements, correct_answers, threshold)

    # Statistiques
    paul_score = scores.get(21, 0)
    rayan_score = scores.get(28, 0)

    ref_paul = ref_scores.get(21, 0)
    ref_rayan = ref_scores.get(28, 0)

    gain_paul = paul_score - ref_paul
    gain_rayan = rayan_score - ref_rayan
    gain_total = gain_paul + gain_rayan

    # Moyenne de tous les étudiants
    all_scores = list(scores.values())
    avg_score = sum(all_scores) / len(all_scores) if all_scores else 0

    # Moyenne de référence
    ref_all_scores = list(ref_scores.values())
    ref_avg = sum(ref_all_scores) / len(ref_all_scores) if ref_all_scores else 0

    delta_avg = avg_score - ref_avg

    # Détection faux positifs
    # Si la moyenne augmente de plus de 2 points, c'est suspect
    has_false_positives = delta_avg > 2.0

    return {
        'threshold': threshold,
        'paul': paul_score,
        'rayan': rayan_score,
        'gain_paul': gain_paul,
        'gain_rayan': gain_rayan,
        'gain_total': gain_total,
        'avg_score': avg_score,
        'delta_avg': delta_avg,
        'false_positives': has_false_positives,
        'all_scores': scores
    }

def main():
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║   ANALYSE DES SEUILS OPTIMAUX - AMC                      ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print()

    # Chemins
    data_dir = Path("data")
    capture_db = data_dir / "capture.sqlite"
    scoring_db = data_dir / "scoring.sqlite"

    if not capture_db.exists() or not scoring_db.exists():
        print("❌ Erreur : Bases de données non trouvées")
        print(f"   capture.sqlite : {capture_db.exists()}")
        print(f"   scoring.sqlite : {scoring_db.exists()}")
        sys.exit(1)

    print("📊 Chargement des données...")

    # Charger les données
    ref_scores = get_current_scores(str(scoring_db))
    measurements = get_zone_measurements(str(capture_db))
    correct_answers = get_correct_answers(str(scoring_db))

    print(f"  ✓ {len(ref_scores)} étudiants")
    print(f"  ✓ {len(measurements)} mesures de cases")
    print(f"  ✓ {len(correct_answers)} questions")
    print()

    # Scores de référence
    ref_paul = ref_scores.get(21, 0)
    ref_rayan = ref_scores.get(28, 0)
    ref_avg = sum(ref_scores.values()) / len(ref_scores) if ref_scores else 0

    print("📋 Scores de référence (seuil actuel ~0.15) :")
    print(f"  • Paul (21) : {ref_paul} / 44")
    print(f"  • Rayan (28) : {ref_rayan} / 44")
    print(f"  • Moyenne classe : {ref_avg:.1f} / 44")
    print()

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔬 TESTS DES SEUILS (0.08 à 0.20)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()

    # Tester différents seuils
    thresholds = [0.08, 0.09, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20]
    results = []

    print(f"{'Seuil':>6} | {'Paul':>4} | {'Rayan':>5} | {'Moy':>5} | {'ΔMoy':>5} | {'+Paul':>5} | {'+Rayan':>6} | {'FP':>3}")
    print("-" * 75)

    best_result = None
    best_gain = 0

    for threshold in thresholds:
        result = test_threshold(threshold, measurements, correct_answers, ref_scores)
        results.append(result)

        # Afficher
        fp_marker = "OUI" if result['false_positives'] else "Non"
        print(f"{result['threshold']:>6.2f} | {result['paul']:>4.0f} | {result['rayan']:>5.0f} | "
              f"{result['avg_score']:>5.1f} | {result['delta_avg']:>+5.1f} | "
              f"{result['gain_paul']:>+5.0f} | {result['gain_rayan']:>+6.0f} | {fp_marker:>3}")

        # Garder le meilleur (sans faux positifs)
        if not result['false_positives'] and result['gain_total'] > best_gain:
            best_gain = result['gain_total']
            best_result = result

    print()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🏆 RECOMMANDATION FINALE")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()

    if best_result:
        print(f"✅ SEUIL OPTIMAL : {best_result['threshold']:.2f}")
        print()
        print("Avec ce seuil :")
        print(f"  • Paul (21) : {best_result['paul']:.0f} / 44  (gain: {best_result['gain_paul']:+.0f})")
        print(f"  • Rayan (28) : {best_result['rayan']:.0f} / 44  (gain: {best_result['gain_rayan']:+.0f})")
        print(f"  • Gain total : {best_result['gain_total']:+.0f} points")
        print(f"  • Moyenne classe : {best_result['avg_score']:.1f} / 44 (Δ: {best_result['delta_avg']:+.1f})")
        print("  • Pas de faux positifs détectés")
        print()
        print("💡 Pour appliquer ce seuil :")
        print(f"   Éditez NEW_AMC_TOUT_EN_UN_OPTIMISE.command")
        print(f"   Ligne 43 : AMC_SEUIL={best_result['threshold']:.2f}")
        print()
    else:
        print("⚠️  Aucun seuil optimal trouvé sans faux positifs")
        print()
        print("Tous les seuils testés créent des faux positifs.")
        print("Cela peut signifier :")
        print("  • Paul et Rayan n'ont pas vraiment répondu")
        print("  • Leurs cases sont trop claires (scan de mauvaise qualité)")
        print("  • Le seuil actuel (0.15) est déjà optimal")
        print()

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()

    # Analyse détaillée
    print("📊 ANALYSE DÉTAILLÉE :")
    print()

    # Évolution des scores Paul + Rayan
    print("Évolution Paul + Rayan :")
    for r in results:
        total_pr = r['paul'] + r['rayan']
        bar_length = int(total_pr / 2)
        bar = "█" * bar_length
        print(f"  {r['threshold']:.2f} : {total_pr:>2.0f} {bar}")
    print()

if __name__ == "__main__":
    main()
