import pandas as pd
from ydata_profiling import ProfileReport

df = pd.read_csv("data_brute/produits.csv")
ProfileReport(df, title="Audit produits BoutiqueCI").to_file("audits/audit_produits.html")