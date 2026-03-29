import { useState, useEffect } from "react";

function App() {
  const [info, setInfo]       = useState(null);
  const [error, setError]     = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch("/api/info")
      .then(r => r.json())
      .then(d => { setInfo(d); setLoading(false); })
      .catch(() => { setError("Cannot reach backend"); setLoading(false); });
  }, []);

  if (loading) return <div style={s.center}><p style={{color:"#fff"}}>Loading...</p></div>;

  return (
    <div style={s.page}>
      <div style={s.card}>
        <h1 style={s.title}>🚀 DevOps Production Platform</h1>
        <p style={s.sub}>Jenkins · Terraform · EKS · Helm · Docker</p>
        {error && <div style={s.error}>⚠️ {error}</div>}
        {info && (
          <div style={s.grid}>
            {[
              ["Service",     info.service],
              ["Version",     info.version],
              ["Environment", info.environment],
              ["Pod",         info.hostname],
            ].map(([label, value]) => (
              <div key={label} style={s.row}>
                <span style={s.label}>{label}</span>
                <span style={s.value}>{value}</span>
              </div>
            ))}
          </div>
        )}
        <div style={s.badges}>
          {["✅ Terraform","✅ EKS","✅ Jenkins","✅ Helm","✅ Docker","✅ Prometheus"].map(b => (
            <span key={b} style={s.badge}>{b}</span>
          ))}
        </div>
      </div>
    </div>
  );
}

const s = {
  page:   { minHeight:"100vh", background:"#0f172a", display:"flex", alignItems:"center", justifyContent:"center", fontFamily:"monospace" },
  card:   { background:"#1e293b", borderRadius:12, padding:"2.5rem", width:"100%", maxWidth:560, boxShadow:"0 25px 50px rgba(0,0,0,.5)" },
  title:  { color:"#f1f5f9", fontSize:"1.5rem", marginBottom:6 },
  sub:    { color:"#475569", fontSize:".8rem", marginBottom:"2rem" },
  grid:   { background:"#0f172a", borderRadius:8, padding:"1rem", marginBottom:"1.5rem" },
  row:    { display:"flex", justifyContent:"space-between", padding:".4rem 0", borderBottom:"1px solid #1e293b" },
  label:  { color:"#64748b", fontSize:".85rem" },
  value:  { color:"#38bdf8", fontSize:".85rem", fontWeight:"bold" },
  badges: { display:"flex", gap:6, flexWrap:"wrap" },
  badge:  { background:"#0f172a", color:"#38bdf8", padding:"4px 10px", borderRadius:20, fontSize:".75rem" },
  error:  { background:"#450a0a", color:"#fca5a5", padding:".75rem", borderRadius:6, marginBottom:"1rem", fontSize:".85rem" },
  center: { display:"flex", alignItems:"center", justifyContent:"center", minHeight:"100vh", background:"#0f172a" },
};

export default App;
