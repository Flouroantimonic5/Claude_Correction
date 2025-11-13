#!/usr/bin/env python3
import sqlite3

conn = sqlite3.connect("data/scoring.sqlite")
cursor = conn.cursor()

print("Vérification scoring_answer...")
print()

# Voir toutes les valeurs de student
cursor.execute("SELECT DISTINCT student FROM scoring_answer ORDER BY student LIMIT 10")
students = cursor.fetchall()
print(f"Students dans scoring_answer : {students}")
print()

# Voir quelques lignes
cursor.execute("SELECT * FROM scoring_answer LIMIT 20")
rows = cursor.fetchall()
print("Premières lignes de scoring_answer :")
for i, row in enumerate(rows, 1):
    student, question, answer, correct, strategy = row
    print(f"  {i}. student={student}, question={question}, answer={answer}, correct={correct}")
print()

# Compter les bonnes réponses par student
cursor.execute("""
    SELECT student, COUNT(*) as nb_correct
    FROM scoring_answer
    WHERE correct = 1
    GROUP BY student
    ORDER BY student
    LIMIT 10
""")
print("Nombre de bonnes réponses par student :")
for row in cursor.fetchall():
    student, nb = row
    print(f"  Student {student} : {nb} bonnes réponses")

conn.close()
