# Privacy Policy

**Effective Date:** January 1, 2026  
**Developer / Publisher:** Creative Bliss Labs  
**Application:** H House — Hostel & Campus Living Management  
**Contact:** [creativeblisslabs@gmail.com](mailto:creativeblisslabs@gmail.com)  

---

### 1. Introduction
Creative Bliss Labs is committed to protecting your privacy and handling your personal information with transparency and care. This Privacy Policy details the types of information we collect, how it is processed and secured, and your rights regarding your personal data when using the **H House** mobile application (Android/iOS) and associated web terminals.

---

### 2. Information We Collect
We collect only the minimum necessary information required to operate hostel accommodation, mess attendance, campus commerce, and resident security services:

1. **Account & Identity Information:**
   * **Resident / Student Details:** Full Name, University/Hostel Email Address, Phone Number, Room/Bed Assignment, Hostel Block identifier, and Student ID.
   * **Authentication:** Authentication tokens and login timestamps managed securely via Supabase Auth and Google OAuth (PKCE flow).
   * **Biometric Authentication:** Face enrollment templates or local biometric flags (`local_auth`) processed locally on your device for fast hostel check-in and attendance verification. Biometric data never leaves your device hardware.
2. **Campus Commerce & Financial Ledger:**
   * **Orders & Cart Data:** Product selections, order timestamp, delivery addresses/room delivery notes, and transaction statuses.
   * **Payment Information:** Payment methods selected (UPI QR code confirmations, cash counters, or campus digital wallet balances). We do not store credit card numbers or banking passwords.
3. **Hostel Operations, Attendance & Gate Pass Records:**
   * **Mess & Hostel Attendance:** Daily check-in timestamps, meal eligibility, and hostel curfew logs.
   * **Outpass & Gate Requests:** Date/time of departure, expected return time, approved destination, and authorized warden approvals.
   * **Maintenance & Complaints:** Resident service requests, issue descriptions, maintenance photos, and resolution status.
4. **Device Permissions & Diagnostics:**
   * **Camera:** Used strictly for scanning POS QR codes, hostel gate passes, and room inventory audits.
   * **Bluetooth & Location:** Used solely to discover and connect to authorized ESC/POS thermal receipt printers (Bluetooth scan never tracks your geographic movements).
   * **Notifications:** Used to deliver critical campus alerts, outpass approvals, order status updates, and emergency notifications (`POST_NOTIFICATIONS`).
   * **Foreground Service & Audio:** Used for campus announcements or audio guidance when active.

---

### 3. How We Use Your Information
Your data is strictly utilized to:
* Verify your resident identity and grant authorized hostel room and facility access.
* Process campus store purchases, canteen orders, and deliver receipts.
* Record official mess and hostel attendance for safety and campus administrative compliance.
* Route maintenance requests, facility complaints, and emergencies to relevant campus staff.
* Prevent unauthorized entry, fraudulent order cancellations, and account compromise.

---

### 4. Zero Advertising & Data Selling
* **Zero Third-Party Advertising:** H House does not contain third-party ad networks (no Google AdMob, Unity, or Meta Audience Network).
* **No Selling of Personal Data:** We never sell, monetize, rent, or trade resident or student personal data, purchase histories, or attendance records to advertisers or third-party data brokers.

---

### 5. Data Security & Storage
* All data transmission between the mobile application and our servers is encrypted using Transport Layer Security (TLS 1.3 / HTTPS).
* Cloud database access is strictly governed by Supabase Row-Level Security (RLS) policies, ensuring residents can only access their authorized records.
* Release builds are hardened with R8 code minification and ProGuard optimization.

---

### 6. Data Retention & Account Deletion
Residents and users retain full control over their data:
* **In-App Account Deletion:** You may request account deletion at any time via **Profile > Settings > Delete Account** or by contacting the campus administrator.
* **Email Data Removal:** You can request the permanent deletion of your profile, purchase records, and identity files by emailing **[creativeblisslabs@gmail.com](mailto:creativeblisslabs@gmail.com)** with the subject line *"Data Deletion Request - H House"*.
* All associated cloud records are permanently purged from active databases within 30 days of verified request.

---

### 7. Children's Privacy
H House is designed for university students, college residents, faculty, and campus administrators (ages 18 and older, or legally enrolled university students). We do not knowingly collect personal information from individuals under the age of 13.

---

### 8. Changes to This Privacy Policy
We may periodically update this Privacy Policy to reflect app enhancements, campus guidelines, or regulatory requirements. Any revisions will update the "Effective Date" at the top of this document.

---

### 9. Contact Us
For any privacy-related questions or data requests, please contact:  
**Creative Bliss Labs**  
Email: [creativeblisslabs@gmail.com](mailto:creativeblisslabs@gmail.com)  
Developer: Creative Bliss Labs
