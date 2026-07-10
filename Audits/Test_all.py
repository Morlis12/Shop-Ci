import duckdb

con = duckdb.connect()

print("--- EXAMEN DES EMAILS DUPLIQUÉS ET DE LEURS DIFFÉRENCES ---")
print(con.sql("""
    WITH emails_dupliques AS (
        -- 1. On trouve d'abord les emails qui apparaissent plus d'une fois
        SELECT trim(lower(email)) as email_clean
        FROM read_csv_auto('../data_brute/clients.csv', all_varchar=true)
        GROUP BY email_clean
        HAVING COUNT(*) > 1
    )
    -- 2. On affiche toutes les lignes brutes de ces clients pour comparer
    SELECT 
        id_client,
        trim(lower(email)) as email,
        nom,
        prenom,
        pays,
        date_inscription
    FROM read_csv_auto('../data_brute/clients.csv', all_varchar=true)
    WHERE trim(lower(email)) IN (SELECT email_clean FROM emails_dupliques)
    ORDER BY email, date_inscription
"""))

# Empêche la fenêtre externe de se refermer immédiatement
input("\nAppuyez sur Entrée pour quitter...")


