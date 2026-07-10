import pandas as pd
from ydata_profiling import ProfileReport

df = pd.read_csv("data_brute/lignes_commande.csv")
ProfileReport(df, title="Audit lignes commandes BoutiqueCI").to_file("audits/audit_lignes_commande.html")