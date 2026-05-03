# 📊 Ucdan Uca Satış və Gəlirlilik Analizi (End-to-End Sales & Profitability Dashboard)

`Excel` `SQL Server` `Power BI` `Data Cleaning` `Data Modeling` `Data Visualization` `Teamwork`

## 📌 Layihənin İcmalı
Bu layihə, şirkətin satış performansını və mənfəət marjalarını analiz etmək üçün 3 nəfərlik peşəkar komanda tərəfindən icra edilmişdir. 
Layihə çərçivəsində 2.3M ₼ həcmində satış datasının təmizlənməsi, modelləşdirilməsi və vizuallaşdırılması ucdan-uca (end-to-end) tamamlanmışdır.

---

## 👥 Komanda və Öhdəliklər (Team & Responsibilities)
Layihənin uğuru hər bir komanda üzvünün öz sahəsindəki peşəkar töhfəsi sayəsində mümkün olmuşdur:

* **Ramal Bəy** – *Data Pre-processing (Excel)* https://www.linkedin.com/in/ramalkazimov/
    * Missing data (çatışmayan məlumatlar) doldurulması.
    * Outliers (anomaliyaların) təmizlənməsi və sütunların formatlanması.
* **Şəbnəm Xanım** – *Data Modeling & SQL Analysis (SQL Server)* https://github.com/shabnamalakbarova
    * Təmizlənmiş datanın SQL-ə miqrasiyası.
    * Power BI üçün sxemlərin Star Schema qurulması və datanın optimallaşdırılması.
* **Nihat Qasımov** – *Data Visualization & BI (Power BI)* https://www.linkedin.com/in/nihat--qasimov/
    * DAX dili ilə KPI-ların hesablanması.
    * İcraçı rəhbərlik (Executive) və Müştəri/Məhsul analitika panellərinin dizaynı.

---

## 🔗 🛠 Texnologiya Steki
* **Cleaning:** Microsoft Excel (Advanced functions)
* **Database & Modeling:** SQL Server (T-SQL, Data Schemas)
* **Visualization:** Power BI (DAX, Interactive Dashboards)

---

## 📁 Layihənin Strukturu (Data Pipeline)

```sql
-- Nümunə: Power BI üçün hazırlanmış strukturun məntiqi
-- 1. Excel: Data Cleaning (Ramal Bəy tərəfindən)
-- 2. SQL: Data Schema & View Creation (Şəbnəm Xanım tərəfindən)
-- 3. Power BI: Visualization & Insights (Nihat Qasımov tərəfindən)

CREATE VIEW v_SalesPerformance AS
SELECT 
    Category,
    TotalSales,
    TotalProfit,
    ProfitMargin
FROM [Structured_Sales_Database]
