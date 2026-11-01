"""Runs the desktop Tax Keeper's own Store.summary() on test/fixtures/ledger_records.json and writes the
expected numbers to test/fixtures/ledger_expected.json. M3's "done when": the app's maths matches this.

Usage (needs PySide6 and the desktop app): python3 -I tool/desktop_reference.py
"""
import importlib.util, json, os, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESKTOP = os.path.expanduser("~/.local/share/tax-keeper/tax_keeper.py")
os.environ["TAXKEEPER_HOME"] = tempfile.mkdtemp(prefix="tk_ref_")
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

spec = importlib.util.spec_from_file_location("tax_keeper", DESKTOP)
tk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tk)

rules = json.load(open(os.path.join(ROOT, "assets/tax_rules/2026.json")))
desk = {c["id"]: c["desktopName"] for c in rules["incomeCategories"] + rules["expenseCategories"]}
records = json.load(open(os.path.join(ROOT, "test/fixtures/ledger_records.json")))

store = tk.Store()
for r in records:
    store.run("INSERT INTO tx (kind,date,description,party,platform,category,amount,fee,business_pct) "
              "VALUES (?,?,?,?,?,?,?,?,?)",
              (r["kind"], r["date"], r.get("description", ""), r.get("party", ""), r.get("platform", ""),
               desk[r["category"]], r["amountCents"] / 100, r.get("feeCents", 0) / 100, r.get("businessPct", 100)))

out = {}
for year in sorted({r["date"][:4] for r in records}):
    s = store.summary(int(year))
    c = lambda x: round(x * 100)
    out[year] = {"lines": {k: c(v) for k, v in s["lines"].items() if v}, "grossCents": c(s["gross"]),
                 "expensesCents": c(s["expenses"]), "netCents": c(s["net"]), "seTaxCents": c(s["se_tax"]),
                 "setAsideCents": c(s["setaside"])}
json.dump(out, open(os.path.join(ROOT, "test/fixtures/ledger_expected.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
