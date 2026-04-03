---
name: aws-invoice-downloader
description: "Download AWS invoice PDFs for a specified billing month. Uses mairu for AWS SSO authentication and the AWS Invoicing API (list-invoice-summaries, get-invoice-pdf). Trigger on: \"請求書ダウンロード\", \"invoice download\", \"AWS請求\", \"月の請求書\", \"AWS invoice\", \"billing PDF\"."
---

# AWS Invoice Downloader

Download all AWS invoice PDFs for a specified billing period using `mairu` + AWS Invoicing API.

## Workflow

1. Confirm parameters with user (year, month, account ID, mairu server/role)
2. Ensure mairu authentication is active
3. Run `scripts/download_invoices.sh`
4. Report results

## Usage

```bash
bash <skill_dir>/scripts/download_invoices.sh \
  --year 2026 --month 3 \
  --account-id 096692119455 \
  --mairu-server ivry \
  --mairu-role "096692119455/ReadOnlyAccess" \
  --output-dir ./aws-invoices-2026-03/
```

### Parameters

| Parameter | Required | Description |
|---|---|---|
| `--year` | Yes | Billing year (YYYY) |
| `--month` | Yes | Billing month (1-12) |
| `--account-id` | Yes | AWS payer account ID |
| `--mairu-server` | Yes | mairu server name for SSO |
| `--mairu-role` | Yes | mairu role (e.g. `096692119455/ReadOnlyAccess`) |
| `--output-dir` | No | Output directory (default: `~/Downloads/invoices/aws-YYYY-MM/`) |

### Default Configuration (ivry)

For ivry organization, use:
- **account-id**: `096692119455` (ivry-inc, payer account)
- **mairu-server**: `ivry`
- **mairu-role**: `096692119455/ReadOnlyAccess`

## Authentication

The script uses `mairu exec` for AWS SSO authentication. If authentication fails:

1. Ask user to run `mairu login <server>` interactively
2. Re-run the script after login completes

## Requirements

- `mairu` CLI
- `aws` CLI v2
- `jq`
- `curl`
- IAM permission: `invoicing:ListInvoiceSummaries`, `invoicing:GetInvoicePDF`

## Output

- PDF files named `{InvoiceID}.pdf` in the output directory
- Summary table with Invoice ID, Entity, Amount, Currency, and download status
