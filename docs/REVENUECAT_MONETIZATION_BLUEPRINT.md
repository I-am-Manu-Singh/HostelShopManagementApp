# Universal RevenueCat Architecture & Monetization Blueprint

This blueprint defines the complete **RevenueCat Entitlement & Billing Architecture** across all 16 applications developed under **Creative Bliss Labs**.

---

## 1. Global Entitlement Hierarchy
Every application follows an unified RevenueCat Entitlement schema:
1. `free_tier`: Core utility, baseline offline tools, ad-free accessibility.
2. `pro_tier`: Advanced automation, unlimited cloud sync, AI assistance, high-precision exports.
3. `enterprise_tier`: Multi-user team management, multi-store/campus fleets, API access, prioritized SLA.

---

## 2. Comprehensive Per-App Monetization Matrix

| # | Application | Platform | Monetization Model | Free Tier (Base) | Pro Tier (`pro_tier`) | Enterprise/Fleet (`enterprise_tier`) |
|:---|:---|:---|:---|:---|:---|:---|
| **1** | **HostelShopManagementApp** | Flutter | Hybrid Freemium + SaaS | Resident room view, personal mess menu, basic POS billing (up to 50 items/mo). | Unlimited POS billing, barcode wedge scanner, expense ledger, multi-room audit. | Multi-hostel campus command, live guard patrol telemetry, automated biometric mess gating. |
| **2** | **TrekBookingApp** | Flutter | Subscription + Commission | Search trails, view basic itineraries, offline packaging checklist. | GPS topographic offline maps, high-altitude weather alerts, guide direct chat. | Commercial trekking agency backend, group expedition permits & insurance automation. |
| **3** | **NitnemGuktaSteek** | Android (KMP) | 100% Free Seva + Voluntary Seva Memberships | Full Nitnem Banis, Steek translations, word-by-word Larivaar audio. | *Voluntary Seva Patron*: Monthly/Yearly contribution badges, cloud reading sync. | *Akhand Seva Sponsor*: Dedicated server funding sponsorship badge. |
| **4** | **TiffinManagement** | Android (KMP) | B2B SaaS Tiered | Single delivery route (up to 15 customers), basic subscription log. | Multi-driver route optimization, automated SMS/WhatsApp alerts, UPI auto-reconciliation. | Multi-kitchen commercial catering, driver live GPS tracking, bulk GST invoicing. |
| **5** | **MedHome** | React Native | Commission + Healthcare Pass | Doctor appointment booking, standard prescription storage. | MedHome CarePass: Priority doctor house-calls, 20% lab test discounts, automated medicine refills. | Family Health Vault (up to 6 members), continuous geriatric health monitoring. |
| **6** | **MerchantApp** | React Native | Merchant POS SaaS | Single POS register, manual inventory entries, daily sales reports. | High-speed barcode POS, multi-vendor credit ledger (Khata), GST invoice export. | Multi-store synchronization, centralized supplier inventory requisition, cashier staff permissions. |
| **7** | **LyftRide** | React Native | Driver SaaS / Commuter Pass | On-demand single cab hailing, standard rate rides. | Commuter Pass: Zero surge pricing, prioritized driver dispatch, corporate invoice generation. | Fleet Operator Manager: Multi-vehicle tracking, driver daily cash reconciliations, mechanic logs. |
| **8** | **OmniMind** | Android (KMP) | Freemium AI Workspace | 3 mind-map workspaces, local markdown notes, standard tree export. | Unlimited visual canvases, on-device AI concept synthesizer, PDF/SVG/OPML infinite export. | Team collaborative infinite board, encrypted organizational cloud vault. |
| **9** | **OmniChessReader** | Android (KMP) | Freemium Engine | 5 board camera scans/day, Stockfish depth 12 evaluation. | Unlimited board diagram optical recognition, Stockfish depth 25 deep analysis, PGN cloud sync. | Chess Coach Suite: Multi-student game database, blunder workbook generator. |
| **10** | **pEQ-App** | Android (KMP) | Freemium DSP Tool | 5-band fixed equalizer, standard system audio routing. | 10-band true Parametric EQ, AutoEq database (5000+ headphone profiles), floating-point 32-bit DSP. | Studio Pro Calibration: Room acoustic impulse response convolution, multi-channel DAC routing. |
| **11** | **pEQ-Learn** | Android (KMP) | Educational Freemium | 3 daily ear training drills (octave bands), basic score tracking. | Unlimited 1/3 octave drills, pink noise & instrument stem training, detailed ear response chart. | Audio School License: Class leaderboard, educator custom syllabus & frequency testing. |
| **12** | **STUDIO V4** | Android Native | Pro Creator Freemium | 2-track audio recorder, standard WAV export (16-bit 44.1kHz). | Unlimited multi-track DAW, parametric EQ & compressor inserts, 32-bit float audio export. | Commercial Studio Master: VST plugin host support, stem multi-export, Dolby Atmos staging. |
| **13** | **Signy-App** | Android (KMP) | AI Accessibility Freemium | 15 camera translation minutes/day, basic sign dictionary. | Unlimited real-time camera ASL/ISL sign-to-speech, custom gesture training, offline AI models. | Institution Tier: Classroom captioning overlay, enterprise healthcare/banking video portal. |
| **14** | **MoonlightWebcam** | Android (KMP) | Hardware Utility Freemium | 720p 30fps Wi-Fi streaming, auto exposure. | 4K 60fps ultra-low latency streaming, manual ISO/shutter/focus controls, USB-OTG tethering. | Studio Broadcaster: Multi-cam NDI stream outputs, green-screen chroma key engine. |
| **15** | **WearProductivityApp** | Android (Wear OS) | Micro-Utility Freemium | 2 active watch complications, standard Pomodoro timer. | Custom haptic focus patterns, unlimited wrist complications, automatic sleep/focus sync. | Team Focus Board: Corporate executive sync & group mindfulness tracking. |
| **16** | **nux-mg-101-quick-tone** | Android Native | Hardware Companion | Basic preset switcher, chromatic tuner. | Full amp parameter tweaking, custom 512/1024pt IR cabinet loader, cloud patch library backup. | Touring Rig Master: Live setlist MIDI automation, gig backup snapshot engine. |

---

## 3. RevenueCat Package & Product Configuration

### In-App Product ID Naming Convention:
- **Monthly Subscription**: `cbl_{app_id}_pro_monthly` (e.g., `cbl_hostel_pro_monthly`)
- **Annual Subscription**: `cbl_{app_id}_pro_yearly` (with 2-month discount pricing)
- **Lifetime Purchase / Non-Consumable**: `cbl_{app_id}_pro_lifetime`
- **Voluntary Seva / Support (Nitnem)**: `cbl_seva_monthly_small`, `cbl_seva_monthly_large`
