# Idee App Mobile Client-Only / Offline-First
_Report generato il 2026-04-20_

---

## 1. HabitStack — Tracker abitudini minimalista

**Descrizione:** App per tracciare abitudini quotidiane con streak, statistiche locali e reminder. Zero backend, tutto su device (SQLite/Core Data). Design pulito, no fluff.

- **Pro:** mercato enorme e dimostrato (Streaks, Habitica), utenti fortemente retention-prone, sviluppabile in 4-6 settimane, nessuna complessità infrastrutturale.
- **Contro:** mercato saturo. Differenziarsi è difficile senza un angolo chiaro. Il churn è alto se l'onboarding non cattura subito.
- **Monetizzazione:** Freemium con paywall su features avanzate (statistiche dettagliate, widget, export CSV). One-time purchase o abbonamento annuale (~€12-18/anno). Modello one-time converte meglio su nicchie produttività.
- **Previsione ricavi annuali:**
  - Pessimista: 200 utenti paganti × €15 = €3.000
  - Realistico: 1.200 utenti paganti × €15 = €18.000
  - Ottimista: 5.000 utenti paganti × €15 = €75.000
- **Business plan sintetico:**
  - Sviluppo: 5-7 settimane (SwiftUI + Jetpack Compose, o Flutter cross-platform)
  - Acquisizione: TikTok/Reddit /r/getdisciplined, ASO aggressivo, nessuna ads a pagamento inizialmente
  - Break-even: ~150 acquisti one-time. Realizzabile in mese 1-2 con una nicchia specifica (es. "per ADHD" o "per atleti").

---

## 2. NoiseMask — Generatore rumori bianchi e suoni ambientali

**Descrizione:** App offline-first per focus e sonno: white noise, brown noise, rain, forest, cafe. Audio bundled localmente, mixer multi-traccia semplice, timer automatico.

- **Pro:** richiesta stabile tutto l'anno, bassissima complessità tecnica, ottima retention perché usata ogni giorno. Buono spazio su Android dove Apple non ha sbarcato nativamente.
- **Contro:** Apple ha integrato "Background Sounds" in iOS 15+, quindi su iOS è più dura. I file audio pesano — storage da gestire. Pochi modi di differenziarsi nel tempo.
- **Monetizzazione:** Freemium: base gratuita con 4-5 suoni, premium one-time (~€5-8) per sbloccare tutto + mixer + timer sleep. Nessun abbonamento — utenti di questo segmento li odiano.
- **Previsione ricavi annuali:**
  - Pessimista: €2.500
  - Realistico: €14.000
  - Ottimista: €40.000
- **Business plan sintetico:**
  - Sviluppo: 3-4 settimane (Flutter, audio con just_audio)
  - Acquisizione: YouTube Shorts "white noise for focus", Reddit /r/sleep, blogger wellness
  - Break-even: ~200 acquisti. Veloce se si punta su Android dove il gap è reale.

---

## 3. BodyLog — Diario allenamento offline con progressione

**Descrizione:** App per tracciare workout in palestra o calisthenics: esercizi, serie/reps/peso, grafici di progressione. 100% locale, no login, export CSV/PDF.

- **Pro:** utenti fitness pagano, retention altissima (dati personali = lock-in), nessun server. TikTok è pieno di fitness content con potenziale organico.
- **Contro:** Strong, Hevy, FitNotes già esistono e sono ben fatti. Senza un angolo (es. calisthenics, powerlifting, donne over 40) è difficile emergere.
- **Monetizzazione:** Freemium — base gratis (3 workout salvabili), premium one-time €9-14 per sbloccare tutto.
- **Previsione ricavi annuali:**
  - Pessimista: €4.000
  - Realistico: €22.000
  - Ottimista: €90.000 (con nicchia non coperta)
- **Business plan sintetico:**
  - Sviluppo: 6-9 settimane per v1 con grafici (React Native + SQLite o Flutter)
  - Acquisizione: creators fitness su IG/TikTok, /r/bodyweightfitness, ASO
  - Break-even: ~500 acquisti. Con differenziazione chiara, realistico in 2-3 mesi.

---

## 4. FocusDraft — Pomodoro timer con session log locale

**Descrizione:** Timer Pomodoro minimalista con log delle sessioni, note rapide per ogni blocco, statistiche settimanali/mensili. Offline, widget home screen, nessun account.

- **Pro:** sviluppo rapidissimo (2-3 settimane), zero infrastruttura, il widget differenzia molto su iOS e Android.
- **Contro:** Mercato più saturo di tutti — Forest, Be Focused, Focus Flow. Senza differenziazione forte è quasi invisibile.
- **Monetizzazione:** One-time purchase (€2,99-4,99). Semplice, senza friction.
- **Previsione ricavi annuali:**
  - Pessimista: €1.500
  - Realistico: €8.000
  - Ottimista: €25.000
- **Business plan sintetico:**
  - Sviluppo: 2-3 settimane, ideale come primo progetto mobile
  - Acquisizione: ProductHunt, HackerNews "Show HN", Reddit /r/productivity
  - Break-even: ~50-100 acquisti. Facile da raggiungere, potenziale limitato.

---

## 5. CaloSnap — Stima calorie da foto con AI on-device

**Descrizione:** Scatta una foto del piatto, l'app stima le calorie con ML locale (CoreML su iOS, ML Kit su Android). Diario alimentare offline, privacy-first — nessuna foto inviata al cloud.

- **Pro:** differenziazione forte ("AI senza mandare le foto a nessuno"), trend privacy, mercato salute con ARPU alto.
- **Contro:** Precisione modelli on-device inferiore a soluzioni cloud. Gestire le aspettative è critico. CoreML/ML Kit richiedono curva di apprendimento. Food recognition accuracy non sempre ottima.
- **Monetizzazione:** Freemium: 10 snap/giorno gratis, premium €3,99/mese o €24,99/anno per snap illimitate + macro target + export.
- **Previsione ricavi annuali:**
  - Pessimista: €3.000
  - Realistico: €20.000
  - Ottimista: €100.000 (se l'accuracy regge)
- **Business plan sintetico:**
  - Sviluppo: 10-14 settimane (la parte ML è la più critica)
  - Acquisizione: YouTube food/fitness creators, TikTok "AI che indovina le calorie", dietisti affiliate
  - Break-even: ~200 abbonamenti annuali. Possibile in 3-6 mesi con canale giusto.

---

## Ranking Consigliato

| # | App | Rischio | Potenziale | Facilità sviluppo |
|---|-----|---------|------------|-------------------|
| 1 | NoiseMask | Basso | Medio-alto | Alta |
| 2 | BodyLog (nicchia) | Medio | Alto | Media |
| 3 | HabitStack (angolo ADHD) | Medio | Medio | Alta |
| 4 | CaloSnap | Alto | Molto alto | Bassa |
| 5 | FocusDraft | Basso | Basso | Alta |

**Consiglio diretto:** se vuoi validare il mercato veloce, parti da NoiseMask o HabitStack con un angolo preciso. Se vuoi scommettere su qualcosa di differenziante con più effort, BodyLog su nicchia calisthenics ha gap reale nel 2026.
