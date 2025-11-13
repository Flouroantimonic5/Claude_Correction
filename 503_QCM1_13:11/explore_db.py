#!/usr/bin/env python3
"""Explorer la structure des bases de données AMC"""

import sqlite3
from pathlib import Path

def explore_database(db_path, db_name):
    """Explore une base SQLite et affiche sa structure"""
    print(f"\n{'='*60}")
    print(f"Base de données : {db_name}")
    print(f"{'='*60}\n")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Lister toutes les tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()

    for table in tables:
        table_name = table[0]
        print(f"\n📋 Table : {table_name}")
        print("-" * 60)

        # Structure de la table
        cursor.execute(f"PRAGMA table_info({table_name});")
        columns = cursor.fetchall()

        print("\nColonnes :")
        for col in columns:
            col_id, name, col_type, not_null, default, pk = col
            print(f"  • {name} ({col_type})")

        # Compter les lignes
        cursor.execute(f"SELECT COUNT(*) FROM {table_name};")
        count = cursor.fetchone()[0]
        print(f"\nNombre de lignes : {count}")

        # Afficher quelques lignes d'exemple
        if count > 0:
            cursor.execute(f"SELECT * FROM {table_name} LIMIT 3;")
            rows = cursor.fetchall()
            print(f"\nExemple de données (3 premières lignes) :")
            for i, row in enumerate(rows, 1):
                print(f"  Ligne {i} : {row[:5]}..." if len(row) > 5 else f"  Ligne {i} : {row}")

    conn.close()

def main():
    data_dir = Path("data")

    # Explorer capture.sqlite
    capture_db = data_dir / "capture.sqlite"
    if capture_db.exists():
        explore_database(str(capture_db), "capture.sqlite")

    # Explorer scoring.sqlite
    scoring_db = data_dir / "scoring.sqlite"
    if scoring_db.exists():
        explore_database(str(scoring_db), "scoring.sqlite")

if __name__ == "__main__":
    main()
