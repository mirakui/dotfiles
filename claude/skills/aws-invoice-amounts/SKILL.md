---
name: aws-invoice-amounts
description: "Generate amounts.json for AWS invoices by merging classification.json with AWS Invoicing API data. Fetches invoice amounts via mairu + AWS API and outputs structured JSON with charges, discounts, taxes. Requires classification.json in the invoice directory. Trigger on: \"amounts生成\", \"generate amounts\", \"請求金額\", \"invoice amounts\", \"金額JSON\"."
---

# AWS Invoice Amounts

Generate `amounts.json` by merging `classification.json` with AWS Invoicing API data (`list-invoice-summaries`).

## Prerequisites

- `classification.json` must exist in the invoice directory (use `aws-invoice-classifier` skill first)
- mairu authentication must be active

## Usage

```bash
bash <skill_dir>/scripts/generate_amounts.sh \
  --year 2026 --month 3 \
  --account-id 096692119455 \
  --mairu-server ivry \
  --mairu-role "096692119455/ReadOnlyAccess" \
  --invoice-dir ~/Downloads/invoices/aws-2026-03
```

### Default Configuration (ivry)

- **account-id**: `096692119455`
- **mairu-server**: `ivry`
- **mairu-role**: `096692119455/ReadOnlyAccess`
- **invoice-dir**: `~/Downloads/invoices/aws-YYYY-MM`

## Output Format

### non-marketplace (USD)

```json
{
  "file": "JPIN26-1129605.pdf",
  "category": "non-marketplace",
  "subcategory": "monthly-usage",
  "label": "ivry-prd",
  "currency": "USD",
  "aws_service_charges": 24846.76,
  "charges": 26042.70,
  "savings_plans": -3088.74,
  "credits_discounts": -365.99,
  "net_charges": 22587.97,
  "jct": 2258.79,
  "total_jpy": 3982752
}
```

### marketplace (JPY)

```json
{
  "file": "JPMPIN26-14103.pdf",
  "category": "marketplace",
  "subcategory": null,
  "label": "datadog",
  "currency": "JPY",
  "charges": 130499,
  "net_charges": 130499,
  "jct": 13050,
  "total": 143549
}
```

## Notes

- IINJP invoices with null TaxCurrencyAmount in API are resolved via their pair invoice
- Sorted by category, subcategory, label
