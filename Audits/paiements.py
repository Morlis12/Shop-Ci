import pandas as pd
from ydata_profiling import ProfileReport

df = pd.read_csv("data_brute/Paiements.csv")
ProfileReport(df, title="Audit paiements BoutiqueCI").to_file("audits/audit_paiements.html")