# Lux

A cross-platform, multi-tenant stock management and profit-tracking application designed for retail spaces, markets, and collaborative sales environments.

## Overview
Lux simplifies inventory management by allowing businesses to dynamically track stock, parse monthly sales reports, and automatically split profits amongst multiple tracked personnel or vendors. Built with a responsive, modern Flutter interface, Lux ensures that store owners and vendors can seamlessly maintain visibility over their product movements and net earnings.

## Key Features
*   **Dynamic Profit Splitting**: Configure vendor-specific prefixes to automatically calculate and assign net profits from bulk sales data.
*   **PDF Report Ingestion**: Effortlessly upload and parse tabular end-of-month PDF sales reports. The system intelligently detects product codes, quantities, and values, and cross-references them against your master catalogue.
*   **Company Management**: Add, edit, or remove personnel and link email addresses to provision secure, tailored dashboard access for vendors.
*   **Centralized Catalogue**: Maintain a global product list with baseline cost and sell prices. Dynamic pricing allows the system to auto-sync prices based on newly parsed PDF data.
*   **Robust Row-Level Security**: Fully backed by Supabase with restrictive SQL policies ensuring users only see data pertinent to their company and role.

## Technology Stack
*   **Frontend**: Flutter / Riverpod / GoRouter
*   **Backend**: Supabase (PostgreSQL / Auth)
*   **PDF Parsing**: Syncfusion Flutter PDF

## Setup
1. Clone the repository.
2. Provide a `.env` file containing `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
3. Run `flutter pub get`.
4. Run `flutter run`.
