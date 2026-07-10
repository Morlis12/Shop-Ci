import pandas as pd
from ydata_profiling import ProfileReport

df = pd.read_csv("data_brute/clients.csv")
ProfileReport(df, title="Audit clients BoutiqueCI").to_file("audits/audit_clients.html")