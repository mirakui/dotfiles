---
name: aws-invoice-classifier
description: "Classify AWS invoice PDFs in a directory and generate classification.json with labels. Read each PDF, identify linked accounts, invoicing entity, marketplace vs non-marketplace, and assign labels. Trigger on: \"請求書分類\", \"invoice classify\", \"請求書ラベリング\", \"invoice label\", \"classify invoices\", \"分類して\", \"ラベリングして\"."
---

# AWS Invoice Classifier

Classify AWS invoice PDFs in a specified directory and output `classification.json`.

## Workflow

1. Read `rules/classification-rules.md` for classification rules and output format
2. List all `*.pdf` files in the target directory
3. Read each PDF (page 1 is usually sufficient; read "Linked Account Allocation" pages too)
4. For each PDF, extract and determine all classification fields per the rules
5. Write `classification.json` to the same directory

## Key Extraction Points per PDF

From **page 1** (Invoice Summary):
- Invoice ID (Tax Invoice Number / Invoice Number)
- Invoicing entity (AWS Japan G.K. vs AWS, Inc.)
- "Purchases on Marketplace" → marketplace
- "AWS Service Charges" → non-marketplace (usually)
- "applied to Invoice #XXXXXXX" → pair_invoice hint (IINJP files)

From **"Linked Account Allocation"** section (usually page 5+):
- Account names and IDs listed under "Activity By Account"

## Rules Reference

Read `rules/classification-rules.md` before starting classification. It contains:
- Invoice ID prefix conventions
- Account ID to name mapping
- Category/subcategory/label determination logic
- Output JSON schema and example
