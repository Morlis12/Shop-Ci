import pandas as pd
from ydata_profiling import ProfileReport

df = pd.read_csv("data_brute/commandes.csv")
ProfileReport(df, title="Audit commandes BoutiqueCI").to_file("audits/audit_commandes.html")