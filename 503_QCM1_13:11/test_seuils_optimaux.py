#!/usr/bin/env python3
"""
Analyse des seuils optimaux pour AMC
Teste différents seuils de noirceur pour maximiser Paul et Rayan
sans créer de faux positifs
"""

import sqlite3
import sys
from pathlib import Path
from collections import defaultdict

def get_current_scores(db_path):
    """Récupère les scores actuels depuis scoring.sqlite"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT student, SUM(score) as total
        FROM scoring_score
        WHERE copy = 0
        GROUP BY student
        ORDER BY student
    """)

    scores = {}
    for row in cursor.fetchall():
        student_id, total = row
        scores[student_id] = total

    conn.close()
    return scores

def get_zone_measurements(capture_db):
    """Récupère toutes les mesures de noirceur"""
    conn = sqlite3.connect(capture_db)
    cursor = conn.cursor()

    # Type 4 = case à cocher (answer box)
    # id_a = question, id_b = answer
    cursor.execute("""
        SELECT student, copy, id_a, id_b, total, black
        FROM capture_zone
        WHERE type = 4 AND copy = 0
        ORDER BY student, id_a, id_b
    """)

    measurements = []
    for row in cursor.fetchall():
        student, copy, question, answer, total, black = row
        if total > 0:
            darkness = black / total
        else:
            darkness = 0

        measurements.append({
            'student': student,
            'question': question,
            'answer': answer,
            'darkness': darkness
        })

    conn.close()
    return measurements

def get_correct_answers(scoring_db):
    """Récupère les bonnes réponses (même pour tous les étudiants)"""
    conn = sqlite3.connect(scoring_db)
    cursor = conn.cursor()

    # Les bonnes réponses sont identiques pour tous les étudiants
    # On prend celles du student 1
    cursor.execute("""
        SELECT question, answer
        FROM scoring_answer
        WHERE student = 1 AND correct = 1
    """)

    correct = defaultdict(list)
    for row in cursor.fetchall():
        question, answer = row
        correct[question].append(answer)

    conn.close()
    return dict(correct)

def get_scoring_strategy(scoring_db):
    """Récupère la stratégie de notation (b=1,m=0 généralement)"""
    conn = sqlite3.connect(scoring_db)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT strategy
        FROM scoring_default
        WHERE type = 1
    """)

    row = cursor.fetchone()
    strategy = row[0] if row else "b=1,m=0"

    conn.close()

    # Parser la stratégie (format : b=1,m=0)
    params = {}
    for part in strategy.split(','):
        if '=' in part:
            key, value = part.split('=')
            params[key.strip()] = float(value.strip())

    return params

def calculate_score_for_question(checked_answers, correct_answers, strategy):
    """Calcule le score pour une question selon la stratégie AMC"""
    b = strategy.get('b', 1)  # Points pour bonne réponse
    m = strategy.get('m', 0)  # Points pour mauvaise réponse

    # Pas de réponse = 0
    if not checked_answers:
        return 0

    # Plusieurs réponses cochées ou mauvaise réponse = pénalité
    if len(checked_answers) > 1:
        return m

    # Une seule réponse cochée
    if checked_answers[0] in correct_answers:
        return b
    else:
        return m

def calculate_scores_with_threshold(measurements, correct_answers, strategy, threshold):
    """Calcule tous les scores avec un seuil donné"""
    # Grouper les réponses par étudiant et question
    student_responses = defaultdict(lambda: defaultdict(list))

    for m in measurements:
        if m['darkness'] >= threshold:
            student = m['student']
            question = m['question']
            answer = m['answer']
            student_responses[student][question].append(answer)

    # Calculer les scores
    scores = defaultdict(float)
    for student in student_responses:
        for question in student_responses[student]:
            checked = student_responses[student][question]
            correct = correct_answers.get(question, [])
            score = calculate_score_for_question(checked, correct, strategy)
            scores[student] += score

    return dict(scores)

def analyze_threshold(threshold, measurements, correct_answers, strategy, ref_scores):
    """Analyse un seuil et retourne les statistiques"""
    scores = calculate_scores_with_threshold(measurements, correct_answers, strategy, threshold)

    # Scores de Paul et Rayan
    paul = scores.get(21, 0)
    rayan = scores.get(28, 0)

    ref_paul = ref_scores.get(21, 0)
    ref_rayan = ref_scores.get(28, 0)

    gain_paul = paul - ref_paul
    gain_rayan = rayan - ref_rayan

    # Moyenne de la classe
    all_scores = list(scores.values())
    avg = sum(all_scores) / len(all_scores) if all_scores else 0

    ref_all = list(ref_scores.values())
    ref_avg = sum(ref_all) / len(ref_all) if ref_all else 0

    delta_avg = avg - ref_avg

    # Détection faux positifs
    # Si moyenne augmente de plus de 1.5 points, suspect
    has_fp = delta_avg > 1.5

    return {
        'threshold': threshold,
        'paul': paul,
        'rayan': rayan,
        'gain_paul': gain_paul,
        'gain_rayan': rayan,
        'avg': avg,
        'delta_avg': delta_avg,
        'false_positives': has_fp,
        'total_gain': gain_paul + gain_rayan
    }

def main():
    print()
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║   TEST DES SEUILS OPTIMAUX - PAUL & RAYAN                ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print()

    # Chemins
    capture_db = "data/capture.sqlite"
    scoring_db = "data/scoring.sqlite"

    if not Path(capture_db).exists() or not Path(scoring_db).exists():
        print("❌ Erreur : Bases de données non trouvées")
        sys.exit(1)

    print("📊 Chargement des données...")

    # Charger les données
    ref_scores = get_current_scores(scoring_db)
    measurements = get_zone_measurements(capture_db)
    correct_answers = get_correct_answers(scoring_db)
    strategy = get_scoring_strategy(scoring_db)

    print(f"  ✓ {len(ref_scores)} étudiants")
    print(f"  ✓ {len(measurements)} mesures de cases")
    print(f"  ✓ {len(correct_answers)} questions")
    print(f"  ✓ Stratégie : {strategy}")
    print()

    # Scores de référence
    ref_paul = ref_scores.get(21, 0)
    ref_rayan = ref_scores.get(28, 0)
    ref_all = list(ref_scores.values())
    ref_avg = sum(ref_all) / len(ref_all) if ref_all else 0

    print("📋 Scores de référence (actuels) :")
    print(f"  • Paul (21) : {ref_paul:.0f} / 44")
    print(f"  • Rayan (28) : {ref_rayan:.0f} / 44")
    print(f"  • Moyenne classe : {ref_avg:.1f} / 44")
    print()

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔬 TESTS DES SEUILS")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()

    # Tester une gamme de seuils
    thresholds = [0.05, 0.06, 0.07, 0.08, 0.09, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20]

    print(f"{'Seuil':>7} │ {'Paul':>5} │ {'Rayan':>6} │ {'Moy':>6} │ {'ΔMoy':>6} │ {'+Paul':>6} │ {'+Rayan':>7} │ {'FP':>4}")
    print("─" * 80)

    results = []
    best_result = None
    best_gain = -999

    for threshold in thresholds:
        result = analyze_threshold(threshold, measurements, correct_answers, strategy, ref_scores)
        results.append(result)

        fp = "OUI" if result['false_positives'] else "Non"
        print(f"{result['threshold']:>7.2f} │ {result['paul']:>5.0f} │ {result['rayan']:>6.0f} │ "
              f"{result['avg']:>6.1f} │ {result['delta_avg']:>+6.1f} │ "
              f"{result['gain_paul']:>+6.0f} │ {result['gain_rayan']:>+7.0f} │ {fp:>4}")

        # Meilleur résultat SANS faux positifs
        if not result['false_positives'] and result['total_gain'] > best_gain:
            best_gain = result['total_gain']
            best_result = result

    print()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🏆 RECOMMANDATION")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()

    if best_result:
        print(f"✅ SEUIL OPTIMAL : {best_result['threshold']:.2f}")
        print()
        print("Avec ce seuil :")
        print(f"  • Paul (21) : {best_result['paul']:.0f} / 44  (gain: {best_result['gain_paul']:+.0f})")
        print(f"  • Rayan (28) : {best_result['rayan']:.0f} / 44  (gain: {best_result['gain_rayan']:+.0f})")
        print(f"  • Gain total : {best_result['total_gain']:+.0f} points")
        print(f"  • Moyenne : {best_result['avg']:.1f} / 44 (Δ: {best_result['delta_avg']:+.1f})")
        print("  • Pas de faux positifs")
        print()
        print("💡 Pour appliquer :")
        print(f"   Éditez NEW_AMC_TOUT_EN_UN_OPTIMISE.command")
        print(f"   Ligne 43 : AMC_SEUIL={best_result['threshold']:.2f}")
    else:
        print("⚠️  Aucun seuil optimal trouvé")
        print()
        print("Tous les seuils testés créent des faux positifs ou")
        print("ne permettent pas d'améliorer Paul et Rayan.")
        print()
        print("Recommandation : Garder le seuil actuel ou vérifier")
        print("la qualité des scans de Paul et Rayan.")

    print()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print()

    # Graphique d'évolution
    print("📊 Évolution Paul + Rayan :")
    print()
    for r in results:
        total = r['paul'] + r['rayan']
        bar_len = int(total / 2)
        bar = "█" * bar_len
        marker = " ⭐" if r == best_result else ""
        print(f"  {r['threshold']:.2f} │ {total:>3.0f} {bar}{marker}")

    print()

if __name__ == "__main__":
    main()
