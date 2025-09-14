# People-Analytics-Inclusion-Diversity-Health-Metrics-Analysis

## 📌 Project Overview
This project analyzes the **PwC HR Diversity & Inclusion dataset** to evaluate workforce health in terms of **representation, attrition, promotions, and equity**.  
The goal is to translate HR metrics into **measurable business impact**, helping leaders understand both organizational equity and the financial costs of workforce disparities.  

---

## ⚙️ Tools & Technologies
- **Python** → Data cleaning and preprocessing  
- **SQL Server** → Data modeling, creation of analytical views, and KPI calculations  
- **Tableau** → Interactive dashboards for executive-level insights  

---

## 📊 Key Analyses
1. **Representation Health**  
   - Gender and nationality distribution across the workforce  
   - Leadership vs overall workforce representation  

2. **Attrition Analysis (FY20)**  
   - Overall attrition = **9.4%**  
   - Women’s attrition = **10.2%** vs Men’s attrition = **8.8%**  

3. **Promotion Equity (FY21)**  
   - Promotion Equity Index (Women) = **0.89**  
   - Indicates women were promoted at 89% of the overall company rate  

4. **Turnover Cost Modeling**  
   - Estimated ~$62K in **excess turnover costs** due to higher female attrition  
   - Cost per leaver estimated at $25K (industry benchmark: SHRM/Deloitte)  

---

## 📈 Dashboard Highlights
The **Tableau dashboard** includes:
- KPI cards: Headcount, Attrition %, Promotion Equity Index, Turnover Cost  
- Gender & nationality representation charts  
- Attrition disparities with financial impact  
- Promotion fairness and performance vs promotion analysis  

---

## 🚀 Project Workflow
1. **Data Cleaning** in Python → removed nulls, standardized formats  
2. **Database Setup** in SQL Server → loaded cleaned data into `hr.hr_clean` table  
3. **SQL Views** → created reusable analytical layers:  
   - `vw_representation_fy20`  
   - `vw_attrition_gender_fy20`  
   - `vw_promotion_equity_gender_fy21`  
   - `vw_attrition_cost_gender_fy20`  
4. **Visualization in Tableau** → connected to SQL Server views and built an executive-style dashboard  

---

## 🔑 Business Impact
- **Identified retention gaps**: higher attrition for women (+1.4 pts vs men)  
- **Exposed advancement inequity**: women’s promotion equity index = **0.89**  
- **Translated HR risk into financial terms**: $62K in excess turnover costs  
