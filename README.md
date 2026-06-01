# Air Quality & Health Data Warehouse NYC

## Deskripsi
Proyek ini mengimplementasikan **Data Warehouse** dan **OLAP** untuk menganalisis kualitas udara dan dampak kesehatan di **New York City**. Dataset mencakup polutan udara (PM2.5, NO2, O3) serta indikator kesehatan (rawat jalan, rawat inap, kematian). Proses ETL dilakukan untuk ekstraksi, transformasi, dan loading data ke **PostgreSQL**, kemudian dibangun **star schema** untuk analisis OLAP. Hasilnya memungkinkan visualisasi insight **temporal**, **geospasial**, dan **kategori indikator** untuk mendukung pengambilan keputusan berbasis data lingkungan dan kesehatan.

---

## Fitur
- Integrasi dataset kualitas udara dan kesehatan publik
- Pembersihan, transformasi, dan pemodelan data ke **star schema**
- Analisis performa query dengan **EXPLAIN ANALYZE** dan **materialized view**
- OLAP Cube untuk agregasi data berdasarkan tahun, lokasi, dan kategori indikator
- Visualisasi tren dan distribusi data

---

## Struktur Repository
├─ data_raw/ # Dataset mentah

├─ data_clean/ # Dataset hasil cleaning

├─ data_batch/ # Batch dataset per periode

├─ output/ # Hasil ETL, CSV dimensi & fact tables

├─ notebooks/ # Jupyter Notebook ETL & analisis

└─ README.md # Dokumentasi proyek


---

## Teknologi
- **Python** (pandas, numpy, matplotlib)
- **PostgreSQL** (star schema, partitioning, materialized view)
- **Atoti** (OLAP cube)
- SQL untuk ETL dan benchmarking
- Git/GitHub untuk versioning

---

## Referensi Dataset & Penelitian
- Dataset: [Air Quality & Health Impacts NYC](https://data.cityofnewyork.us/Environment/Air-Quality-and-Health-Impacts/c3uy-2p5r/about_data)
- Penelitian:
  - Manisalidis et al., 2020: [DOI 10.3389/fpubh.2020.00014](https://doi.org/10.3389/fpubh.2020.00014)
  - Agarwal et al., 2021: [DOI 10.1016/j.procs.2021.08.004](https://doi.org/10.1016/j.procs.2021.08.004)
  - Sunjaya et al., 2021: [DOI 10.1007/s12145-021-00631-4](https://doi.org/10.1007/s12145-021-00631-4)

---
